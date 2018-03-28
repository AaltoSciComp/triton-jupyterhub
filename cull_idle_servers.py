#!/usr/bin/env python
"""script to monitor and cull idle single-user servers

Caveats:

last_activity is not updated with high frequency,
so cull timeout should be greater than the sum of:

- single-user websocket ping interval (default: 30s)
- JupyterHub.last_activity_interval (default: 5 minutes)

You can run this as a service managed by JupyterHub with this in your config::


    c.JupyterHub.services = [
        {
            'name': 'cull-idle',
            'admin': True,
            'command': 'python cull_idle_servers.py --timeout=3600'.split(),
        }
    ]

Or run it manually by generating an API token and storing it in `JUPYTERHUB_API_TOKEN`:

    export JUPYTERHUB_API_TOKEN=`jupyterhub token`
    python cull_idle_servers.py [--timeout=900] [--url=http://127.0.0.1:8081/hub/api]
"""

import datetime
import json
import os
import sqlite3

from dateutil.parser import parse as parse_date

from tornado.gen import coroutine
from tornado.log import app_log
from tornado.httpclient import AsyncHTTPClient, HTTPRequest
from tornado.ioloop import IOLoop, PeriodicCallback
from tornado.options import define, options, parse_command_line


@coroutine
def cull_idle(url, api_token, timeout, cull_users=False):
    """Shutdown idle single-user servers

    If cull_users, inactive *users* will be deleted as well.
    """
    auth_header = {
            'Authorization': 'token %s' % api_token
        }
    req = HTTPRequest(url=url + '/users',
        headers=auth_header,
    )
    now = datetime.datetime.utcnow()
    cull_limit = now - datetime.timedelta(seconds=timeout)
    client = AsyncHTTPClient()
    resp = yield client.fetch(req)
    users = json.loads(resp.body.decode('utf8', 'replace'))
    futures = []

    @coroutine
    def cull_one(user, last_activity, log_data):
        """cull one user"""

        # shutdown server first. Hub doesn't allow deleting users with running servers.
        if user['server']:
            app_log.info("Culling server for %s (inactive since %s: %s)", user['name'], last_activity, log_data)
            req = HTTPRequest(url=url + '/users/%s/server' % user['name'],
                method='DELETE',
                headers=auth_header,
            )
            yield client.fetch(req)
        if cull_users:
            app_log.info("Culling user %s (inactive since %s: %s)", user['name'], last_activity, log_data)
            req = HTTPRequest(url=url + '/users/%s' % user['name'],
                method='DELETE',
                headers=auth_header,
            )
            yield client.fetch(req)

    # Find the total active memory that is being used, by adding up
    # all running servers.  This could someday be used to 
    total_mem = 0
    conn = sqlite3.connect(options.server_db)
    cur = conn.execute('SELECT state FROM spawners WHERE server_id is not NULL')
    for active_spawner in cur:
        state = json.loads(active_spawner[0])
        mem = state['child_conf']['req_memory']
        total_mem += int(mem)
    # END

    for user in users:
        if not user['server'] and not cull_users:
            # server not running and not culling users, nothing to do
            continue
        last_activity = parse_date(user['last_activity'])

        # Advanced culling: cull depending on the spawner-specific
        # timeout.  This is specific to the batchspawner, and the
        # options must have req_culltime defined.  Default zero, which
        # means do not cull.
        cur = conn.execute('SELECT users.name, spawners.state FROM users LEFT JOIN spawners ON (users.id=spawners.user_id) WHERE users.name=?', (user['name'],))
        username, spawner_data = cur.fetchone()
        spawner_data = json.loads(spawner_data)
        mem = spawner_data['child_conf']['req_memory']
        cull_time = spawner_data['child_conf'].get('req_culltime', 365*24*60)  # default in a long time
        profile = spawner_data.get('profile', None)    # from ProflieSpawner name (second argument)
        #print(f"{username}: {total_mem} {mem} {cull_time} {user['last_activity']}")
        # Add extra logic here.

        #if last_activity < cull_limit:
        if cull_time != 0 and last_activity < now - datetime.timedelta(seconds=cull_time):
            futures.append((user['name'], cull_one(user, last_activity, dict(profile=profile,cull_time=cull_time, mem=mem))))
        else:
            app_log.debug("Not culling %s (active since %s)", user['name'], last_activity)

    for (name, f) in futures:
        yield f
        app_log.debug("Finished culling %s", name)

    conn.close() # close sqlite DB


if __name__ == '__main__':
    define('url', default=os.environ.get('JUPYTERHUB_API_URL'), help="The JupyterHub API URL")
    define('timeout', default=600, help="The idle timeout (in seconds)")
    define('cull_every', default=0, help="The interval (in seconds) for checking for idle servers to cull")
    define('server_db', help="Jupyterhub DB to use to cull idle servers")
    define('cull_users', default=False,
        help="""Cull users in addition to servers.
                This is for use in temporary-user cases such as tmpnb.""",
    )

    parse_command_line()
    if not options.cull_every:
        options.cull_every = options.timeout // 2

    api_token = os.environ['JUPYTERHUB_API_TOKEN']

    loop = IOLoop.current()
    cull = lambda : cull_idle(options.url, api_token, options.timeout, options.cull_users)
    # run once before scheduling periodic call
    loop.run_sync(cull)
    # schedule periodic cull
    pc = PeriodicCallback(cull, 1e3 * options.cull_every)
    pc.start()
    try:
        loop.start()
    except KeyboardInterrupt:
        pass

