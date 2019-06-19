# JupyterHub for HPC clusters

This repository contains JupyterHub configuration for running it on
HPC clusters.
[Batchspawner](https://github.com/jupyterhub/batchspawner) is what
actually provides the Slurm integration, so this repository is mainly configuration and integration.  [Makefile](Makefile) supposubly automates the installation, but in practice it will only guide you in the steps you need to take.

Many uses of JupyterHub involved containers or single-user
environments.  In our model, Jupyter is not the primary tool, the cluster is
the primary tool and we try to provide an easy entry point, instead of a
replacement service.  This means *at least* we provice accesss to all the data in the
cluster, and preferably all the software, etc.


Jupyter projects from Aalto Science-IT:

* This repository which contains the actual Jupyterhub software
  installation configuration - all can be done as a normal user.

* Our ansible configuration for cluster deployment (currently minimal
  - deploys system config to CentOS7, but the actual Aalto configuration is
  seprately managed).  This does all administrator setup:
  https://github.com/AaltoScienceIT/ansible-role-fgci-jupyterhub

* User instructions: http://scicomp.aalto.fi/triton/apps/jupyter.html
  (read this to see our vision from a user's perspective).

* Jupyter for light computing/teaching using kubernetes (this repo is
  HPC jupyterhub): https://github.com/AaltoScienceIT/jupyterhub-aalto


Key dependencies from Jupyter:
* JupyterHub: https://github.com/jupyterhub/jupyterhub
* Batchspawner: https://github.com/jupyterhub/batchspawner
* Slurm config - currently not anywhere.


You may also be interested in:
* CSC Notebooks service - epheremal data only, better for small
  workshops.  https://github.com/CSCfi/pebbles



# Instructions for use

Let's say you want to use this repository to set up your own HPC
JupyterHub.  Follow these steps:

* Understand a bit about HPC and Jupyter.  These instructions aren't
  that great yet and can only serve as a guideline, not a recipe.  Be
  ready to tell us about things that don't work and contribute back.

* Clone this repository onto a shared filesystem (we use a dedicated
  virtual node, resources don't need to be large).  This becomes the
  base software installation for the hub (world-readable,
  admin-writeable).  Set up miniconda using the `setup_conda` Makefile
  target.

* Install JupyterHub using the `install_all` Makefile targets.

* Create a `jupyterhub-daemon` user.

* Set up the server with HTTP server, `sudo`, etc.  This is all
  defined in
  [ansible-role-fgci-jupyterhub](https://github.com/AaltoScienceIT/ansible-role-fgci-jupyterhub).
  You can see just what happens in the [tasks
  file](https://github.com/AaltoScienceIT/ansible-role-fgci-jupyterhub/blob/master/tasks/main.yml).
  This does the following things (CentOS 7, may need changes for
  others):

  * Install and configure Apache as a frontend reverse proxy

  * Set up `sudoers` for `jupyterhub-daemon`.

  * Set up basic files in `/etc/jupyterhub`

  * Set up systemd for `jupyterhub` and `configurable-http-proxy`.

  * Set up Shibboleth web server authentication.  (Warning: shibboleth
    is magic, no promises how well this works for others).  This
    probably needs modification for non-Finnish deployments.

* Things that definitely need local tuning:

  * Installation of kernels


# Vision and design

JupyterHub should be a frontend to already-existing resources, not
seen as a separate service.  Anywhere you'd have an SSH server, have
JupyterHub too.

See our [user
instructions](http://scicomp.aalto.fi/triton/apps/jupyter.html) for
the user-centric view.


## Base environment

JupyterHub, the single-user servers, etc, are installed in a dedicated
miniconda environment.  This runs the servers, but no user code (they
all run in kernels that uses the rest of the cluster software, see
"software" below).


## Computational resources

Servers run in the Slurm queue - we have two nodes dedicated for
interactive use, so we put the servers there.  Jupyter has a very
different usage pattern than normal HPC work - CPUs are idle most of
the time, and memory usage is unknown.  Thus, these nodes are
oversubscribed in CPU (currently at least 10x).  They *should* be
oversubscribed in memory, but that is hard for our slurm right now
since globally it is a consumable resource.  Currently, this is
handled by using Slurm cgroups to limit memory: processes can go above
their requested memory by a certain amount (5x), as long as there's
enough resources available.

We provide various time vs memory tradeoffs - you can use small memory server
that will stay running a long time, or a large amonut of memory that
will be automatically culled sooner if it is inactive.  Finding the
right balances of time and memory will be an ongoing challenge.

We have "jupyter-short" and "jupyter-long" partitions, and a
"jupyter-overflow" overlapping with basic batch partitions that is
only used once the basic ones fill up.


## Spawning single-user servers

After a user logs in, they spawn their single-user server.  This code
is running as their own uid in Slurm on nodes.
[batchspawner](https://github.com/jupyterhub/batchspawner) is the
resource manager in JupyterHub and provides the interface to Slurm.
We are active developers on this.


## Software and kernels

We don't install special software for JupyterHub kernels - we have a
cluster with lots of software installed.  Instead, we provide
integration to that.  The `Makefile` has some code to automatically
install a bunch of Python kernels from Lmod, and a few more that are
automatic or semi-automatic.  The idea is you should be able to switch
between any software on the cluster easily.  Our package
[envkernel](https://github.com/NordicHPC/envkernel) helps with that.

[jupyter-lmod](https://github.com/cmd-ntrf/jupyter-lmod) provides
integration of Lmod to Jupyter Notebooks.  Using the "Softwares" tab,
you can load and unload modules and this takes effect when you start
notebooks - nice but they are global to all notebooks, and UI is a bit
confusing.


## Login

Log in is via the Jupyterhub PAM authentication module (since on
cluster nodes, PAM already works).  In the future, we hope to use
Shibboleth but as you can guess that is not trivial.  You must have a
cluster account to be able to use the service, and your JupyterHub
account *is* your cluster account.


## Web server

Apache is used as a reverse proxy for ingress, which does SSL
termination.  If you are *not* in the university network, you have to
pass Shibboleth authentication at the web server level (befor reaching
any JupyterHub code) and *then* log in with JupyterHub PAM
authentication.  This gives us enough security to allow access from
the whole Internet.


## Configuration

The `jupyterhub_config.py` file has all of important config options.

We pre-install a lot of useful extensions for users.

We use ProfileSpawner to provide a form that lets you pick what
resources you need.


## Security

According to the JupyterHub docs, when served on a single domain,
users can't be able to configure their own server (to prevent XSS and
the like).  I have carefully tracked this down and think that our
setup satisfies this.

Obviously, basic software security is very important when run on a
cluster with live data.

I have written long documentation on my security analysis which I will
paste here later.


## Using this deployment

The Ansible role can be used to set up some of the software - warning:
not very well developed.

The other installation can be somewhat done automatically using the
`Makefile`.  Yes, it's a Makefile, which doesn't suit this very well.
It's more like a shell script that you can selectively run parts of.
It should be re-done once we know where we are going.

No guarentees about anything.  This may help guide you, but you'll
need to help generalize.

Please send feedback and contribute.



# Problems in the wild

* Error reporting could be better...

* User loads modules in `.bashrc` and adjusts `$MODULEPATH`.  Loading
  some kernels that depend on certain modules no longer works and they
  keep restarting.

* nbdime is important, but needs some thought to make it available
  globally from within a conda env.  Do we install globally?  Do we
  use from within conda env?

* Not a problem, but there is a lot of potential for courses and
  workshops.  A bit of integration could make things even easier
  (e.g. spawner which copies the right base files to your working
  dir).



# Contact

Richard Darst
[email](https://people.aalto.fi/index.html?language=english#richard_darst),
Aalto University
