
default:
	echo "choose command: run"
run:
	jupyterhub -f jupyterhub_config.py
#	--Class.trait=x   for command line config

# TODO
# SSL
# move cookie secret elsewhere

# - handle log files
# - move sjupyter here
# - kernels

# document:
# - proxy
# - jupyterlab
# - the .jupyterhub-tree directory

default:
	echo "Must give a command to run"

restart:
	systemctl stop jupyterhub

emergency_stop:
	systemctl restart jupyterhub



setup_conda:
	false
	sh ../Miniconda3-latest-Linux-x86_64.sh -p $PWD/miniconda



# This is the very first setup that is needed.
setup_packages:
	false
#	# MUST SOURCE THIS YOURSELF BEFORE RUNNING, outside of Make.
#	source activate $PWD/miniconda
#	#
	test ! -z "$CONDA_PREFIX"
	conda install -c conda-forge jupyterhub
	git clone gh:jupyterhub/batchspawner
	pip install -e batchspawner/
	pip install git+https://github.com/jupyterhub/wrapspawner

	conda install notebook # only where it is being run

	pip install jupyterlab
	jupyter serverextension enable --py jupyterlab --sys-prefix



# Done on the management node.
user_setup:
#	#adduser --user-group --no-create-home jupyterhub-daemon
#	#make -C /var/yp



# This is the place where all kernels are installed
# The jupyter kernelspec https://jupyter-client.readthedocs.io/en/stable/kernels.html
KERNEL_PREFIX=/share/apps/jupyterhub/live/miniconda/

# Note: Take the lmod environment:
# ( echo "  \"env\": {" ; for x in LD_LIBRARY_PATH LIBRARY_PATH MANPATH PATH PKG_CONFIG_PATH ; do echo "    \"$x\": \"${!x}\"", ; done ; echo "  }" ) >> ~/.local/share/jupyter/kernels/ir/kernel.json



# Install the different extensions to jupyter
# NOTE: activate the anaconda environ first.
extensions_install:
	test ! -z "$CONDA_PREFIX"
	jupyter kernelspec list

#	# Widgets
	pip install ipywidgets
	jupyter nbextension enable --py widgetsnbextension --sys-prefix

#	# Notebook diff and merge tools
	pip install nbdime
	nbdime reg-extensions --sys-prefix

#	# Lmod integration
#	# https://github.com/cmd-ntrf/jupyter-lmod
	pip install jupyterlmod
	jupyter nbextension install --py jupyterlmod --sys-prefix
	jupyter nbextension enable jupyterlmod --py --sys-prefix
	jupyter serverextension enable --py jupyterlmod --sys-prefix

#	# javascript extensions for various things
	pip install jupyter_contrib_nbextensions
	jupyter contrib nbextension install --sys-prefix
#	#jupyter nbextension enable [...name...]
	jupyter nbextension enable varInspector/main --sys-prefix



# Install kernels.  These require manual work so far.
kernels_manual:
	false

#	# MATLAB
#	# https://github.com/imatlab/imatlab
#	# https://se.mathworks.com/help/matlab/matlab_external/install-the-matlab-engine-for-python.html
	cd /share/apps/matlab/R2017b/extern/engines/python/ && python setup.py install
	pip install imatlab
#	# MANUAL: add "env": {"LD_PRELOAD": "/share/apps/jupyterhub/live/miniconda/lib/libstdc++.so" }
#       # to /share/apps/jupyterhub/live/miniconda/share/jupyter/kernels/matlab/kernel.json

# 	# MATLAB alternative
#	alternative but seems worse
#	pip install matlab_kernel

#	# R
#	# https://irkernel.github.io/installation/
#	# Needs to be installed in R, then installed from there.

#	# BASH
#	# https://github.com/takluyver/bash_kernel
	pip install bash_kernel
	python -m bash_kernel.install --sys-prefix

	jupyter kernelspec list



# These kernels can be installed automatically: just source anaconda and run this
CONDA_AUTO_KERNELS="anaconda2/5.1.0-cpu anaconda2/5.1.0-gpu anaconda3/5.1.0-cpu anaconda3/5.1.0-gpu"
kernels_auto:
	( ml purge ; ml load anaconda2/latest ; ipython kernel install --name=python2 --display="Python 2/anaconda2/latest" --prefix=/share/apps/jupyterhub/live/miniconda/ )
	( ml purge ; ml load anaconda3/latest ; ipython kernel install --name=python3 --display="Python 3/anaconda3/latest" --prefix=/share/apps/jupyterhub/live/miniconda/ )
	for mod in $(CONDA_AUTO_KERNELS) ; do ( ml purge ; ml load $$mod ; ipython kernel install --name=`echo $$mod | tr / _` --display="$$mod" --prefix=/share/apps/jupyterhub/live/miniconda/ ) ; done
