# Automation for setting up JupyterHub on a HPC cluster.
#
# This Makefile is a hack, and actually serves the role of a piecewise
# shell script which does the setup and documents some important
# management commands.  Not all pieces necessarily work - please
# understand everything before you run it.
#
# The install-related targes *should* mostly work and generally should
# be general work, and we should try to make them work for others,
# too.  Install-related targets should be idempotent (but sometimes if
# re-run, they won't do something that is needed).
#
# Dev run: sudo -u jupyterhub-daemon /bin/bash -c ". miniconda/bin/activate; DEV=1 jupyterhub -f jupyterhub_config.py"

# TODO

# document:
# - proxy
# - jupyterlab
# - the .jupyterhub-tree directory



default:
	@echo "Must specify target to run."
run:
	jupyterhub -f jupyterhub_config.py
#	    --Class.trait=x   for command line config

restart:
	systemctl stop jupyterhub

emergency_stop:
	systemctl restart jupyterhub


# INSTALLATION
#
# To do full installation, *first* you must setup miniconda first:
#     make setup_conda
#     source miniconda/bin/activate
# then install_all:
install_all: setup_core extensions_install kernels_auto kernels_manual
upgrade: setup_core extensions_install

setup_conda:
#	false
	sh ../Miniconda3-latest-Linux-x86_64.sh -s -p $(PWD)/miniconda -b
	echo 'Remember to "source miniconda/bin/activate"'

# This is the very first setup that is needed.
setup_core:
#	false
#	# MUST SOURCE THIS YOURSELF BEFORE RUNNING, outside of Make.
#	source activate $PWD/miniconda
#	#
	test ! -z "$(CONDA_PREFIX)"
	conda install -c conda-forge jupyterhub conda
	test -d batchspawner || git clone https://github.com/jupyterhub/batchspawner
	pip install -e batchspawner/
	test -d wrapspawner || git clone https://github.com/jupyterhub/wrapspawner
	pip install -e wrapspawner
	conda install pycurl  # for cull_idle_servers.py
	conda install -c conda-forge async_generator  # jupyterhub 0.9, remove later

	conda install notebook # only where it is being run
	conda install nbconvert

	pip install --upgrade jupyterlab
	jupyter serverextension enable --py jupyterlab --sys-prefix
#	jupyter labextension install @jupyterlab/hub-extension

#	# Make a directory with only node in it - so that users can
#	# manage extensions themselves.
	mkdir -p $(CONDA_PREFIX)/bin-minimal
	ln -s ../bin/node $(CONDA_PREFIX)/bin-minimal/node


# Done on the management node.
user_setup:
	echo "no-op: do on other host"
#	#adduser --user-group --no-create-home jupyterhub-daemon
#	#make -C /var/yp



# This is the place where all kernels are installed
# The jupyter kernelspec https://jupyter-client.readthedocs.io/en/stable/kernels.html
KERNEL_PREFIX=$(CONDA_PREFIX)/

# Note: Take the lmod environment:
# ( echo "  \"env\": {" ; for x in LD_LIBRARY_PATH LIBRARY_PATH MANPATH PATH PKG_CONFIG_PATH ; do echo "    \"$x\": \"${!x}\"", ; done ; echo "  }" ) >> ~/.local/share/jupyter/kernels/ir/kernel.json



# Install the different extensions to jupyter
# NOTE: activate the anaconda environ first.
extensions_install:
	test ! -z "$(CONDA_PREFIX)"
	jupyter kernelspec list

#	# Widgets
	pip install --upgrade ipywidgets
	jupyter nbextension enable --py widgetsnbextension --sys-prefix
	jupyter labextension install @jupyter-widgets/jupyterlab-manager

#	# Notebook diff and merge tools
	pip install --upgrade nbdime
	nbdime extensions --enable --sys-prefix
	jupyter labextension enable nbdime
#	git clone gh:jupyter/nbdime ; pip install nbdime/    # fixes current bug wrt jupyterhub usage in 0.4.1

#	# Lmod integration
#	# https://github.com/cmd-ntrf/jupyter-lmod
	pip install --upgrade jupyterlmod
	jupyter nbextension install --py jupyterlmod --sys-prefix
	jupyter serverextension enable --py jupyterlmod --sys-prefix
	jupyter nbextension enable jupyterlmod --py --sys-prefix
	jupyter labextension install jupyterlab-lmod

#	# javascript extensions for various things
	pip install --upgrade jupyter_contrib_nbextensions
	jupyter contrib nbextension install --sys-prefix
#	#jupyter nbextension enable [...name...]
#	jupyter nbextension enable varInspector/main --sys-prefix  # Causes random slowdown.

	jupyter labextension install @jupyterlab/git --no-build
	pip install --upgrade jupyterlab-git
	jupyter serverextension enable --py jupyterlab_git

#	# Jupytext - text-based formats for notebooks
	conda install -c conda-forge jupytext

#	# Jupyterlab-slurm (not at 1.0 yet)
	pip install jupyterlab_slurm
	jupyter labextension install jupyterlab-slurm --no-build

#	jupyter-matplotlib
	jupyter labextension install jupyter-matplotlib --no-build

# 	Recents and favorites
	jupyter labextension install jupyterlab-recents --no-build
	jupyter labextension install jupyterlab-favorites --no-build

	jupyter lab build

#	# envkernel - to install kernels in lmod.
	pip install git+https://github.com/NordicHPC/envkernel

#  These kernels can be installed automatically: just source anaconda and run this
CONDA_AUTO_KERNELS=pypy3/5.10.1-py3.5 pypy2/5.10.0-py2.7

kernels_auto:
	test ! -z "$(CONDA_PREFIX)"

#	# Bash
#	# https://github.com/takluyver/bash_kernel
	pip install --upgrade bash_kernel
	python -m bash_kernel.install --sys-prefix

#	# Various Python kernels
	( ml purge ; ml load anaconda ; ipython kernel install --name=python3 --prefix=$(KERNEL_PREFIX) )
#	#( ml purge ; ml load anaconda2/latest ; ipython kernel install --name=python2 --prefix=$(KERNEL_PREFIX) )
	( ml purge ; ml load anaconda3/latest ; ipython kernel install --name=python3-old --prefix=$(KERNEL_PREFIX) )
	envkernel lmod --name=python3 --kernel-template=python3 anaconda/latest --display-name="Python 3/anaconda" --prefix=$(KERNEL_PREFIX)
#	envkernel lmod --name=python2 --kernel-template=python2 anaconda2/latest --display-name="(old) Python 2/anaconda2/latest" --prefix=$(KERNEL_PREFIX)
	envkernel lmod --name=python3-old --kernel-template=python3-old anaconda3/latest --display-name="(old) Python 3/anaconda3/latest" --prefix=$(KERNEL_PREFIX)

#	# Automatic kernels, everything in the list above.
	for mod in $(CONDA_AUTO_KERNELS) ; do \
		( ml purge ; ml load $$mod ; ipython kernel install --name=`echo $$mod | tr / _` --display-name="$$mod" --prefix=$(KERNEL_PREFIX) ; ) ; \
		envkernel lmod --name=`echo $$mod | tr / _` --kernel-template=`echo $$mod | tr / _` --prefix=$(KERNEL_PREFIX) $$mod  ; \
	done

#	# Matlab (imatlab, not using older matlab_kernel any more).
	cd /share/apps/matlab/R2019a/extern/engines/python/ && python setup.py install
	pip install --upgrade imatlab
	python -m imatlab install --sys-prefix --name=imatlab --display-name="Matlab r2019a"
	envkernel lmod --name=imatlab --kernel-template=imatlab --sys-prefix --env=LD_PRELOAD=/share/apps/jupyterhub/live/miniconda/lib/libstdc++.so matlab/r2019a

#	IRkernel needs to be updated
	( ml load r-irkernel/1.1-python3 ; Rscript -e 'IRkernel::installspec(user = FALSE)' )
	envkernel lmod --name=ir      --kernel-template=ir              --sys-prefix r-irkernel/1.1-python3 --display-name="R"
	( ml load r-irkernel/1.1-python3 ; Rscript -e 'IRkernel::installspec(user = FALSE, name="ir-safe")' )
	envkernel lmod --name=ir-safe --kernel-template=ir-safe --purge --sys-prefix r-irkernel/1.1-python3 --display-name="R (safe)"

	chmod -R a+rX $(CONDA_PREFIX)/share/jupyter/kernels/
	jupyter kernelspec list


# Install kernels.  These require manual work so far.
kernels_manual:
	test ! -z "$(CONDA_PREFIX)"

#	# R
#	# https://irkernel.github.io/installation/
#	# Needs to be installed in R, then installed from there.

	jupyter kernelspec list

