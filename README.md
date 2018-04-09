# JupyterHub for HPC clusters

This repository contains JupyterHub configuration for running it on
HPC clusters.
[Batchspawner](https://github.com/jupyterhub/batchspawner) is what
actually provides the Slurm integration, so our work is mainly
configuration and practical stuff.

Many uses of JupyterHub involved containers or single-user
environments.  In our model, Jupyter is not the primary tool, but the
cluster, and we try to provide an easy entry point, insteda of a
replacement.  This means at least accesss to all the data in the
cluster.

Key dependencies:
* JupyterHub: https://github.com/jupyterhub/jupyterhub
* Batchspawner: https://github.com/jupyterhub/batchspawner
* Our ansible configuration for cluster deployment (currently minimal
  - deploys system config to CentOS7, but actual configuration is
  seprately managed.)
* This repository which contains the actual Jupyterhub configuration
* User instructions: http://scicomp.aalto.fi/triton/apps/jupyter.html
  (read this to see our vision from a user's perspective)
* Slurm config - currently not anywhere.

You may also be interested in:
* CSC Notebooks service - epheremal data only, better for small
  workshops.  https://github.com/CSCfi/pebbles


# Vision and design

JupyterHub should be a frontend to already-existing resources.

See our [user
instructions](http://scicomp.aalto.fi/triton/apps/jupyter.html) for
the user-centric view.


## Base environment

JupyterHub, the single-user servers, etc, are installed in a
single-use miniconda environment.  This runs the servers, but no user
code (see software below).


## Computational resources

Servers run in the Slurm queue - we have two nodes dedicated for
interactive use, so we put the servers there.  Jupyter has a very
different usage pattern than normal HPC work - CPUs are idle most of
the time, and memory usage is unknown.  Thus, these nodes are
oversubscribed in CPU (currently 4x).  They *should* be oversubscribed
in memory, but that is hard for our slurm right now since globally it
is a consumable resource.  We are debating how to handle this - we can
fake `RealMemory` to something higher.  Also swap could actually be
useful on these nodes.

We provide various time vs memory tradeoffs - you can use small memory
that will stay running a long time, or a large amonut of memory that
will be automatically culled sooner if it is inactive.  Finding the
right balances of time and memory will be an ongoing challenge.

We have "jupyter-short" and "jupyter-long" partitions, and a
"jupyter-overflow" overlapping with basic batch partitions that is
only used once the basic ones fill up.


## Software

We don't install special software for JupyterHub kernels - we have
a cluster with lots of software installed.  Instead, we provide
integration to that.  The `Makefile` has some code to automatically
install a bunch of Python kernels from Lmod, and a few more that are
automatic or semi-automatic.  The idea is you should be able to switch between

[jupyter-lmod](https://github.com/cmd-ntrf/jupyter-lmod) provides
integration of Lmod to Jupyter Notebooks.  Using the "Softwares" tab,
you can load and unload modules and this takes effect when you start
notebooks - nice but they are global and UI is a bit confusing.


## Login

Log in is via the Jupyterhub PAM authentication module.  In the
future, we hope to use Shibboleth but as you can guess that is not
trivial.  You must have a cluster account to be able to use the
service, and your JupyterHub account *is* your cluster account.


## Configuration

The jupyterhub_config.py file has all of important config options.

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
