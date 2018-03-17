
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


setup:
	false
#	ml load anaconda3
#	ml load teflon
#	conda create --prefix $PWD/conda python pip ipython
	sh ../Miniconda3-latest-Linux-x86_64.sh -p $PWD/miniconda
	source activate $PWD/miniconda
	conda install -c conda-forge jupyterhub
#	( umask 700 ; openssl rand -hex 32 > jupyterhub_cookie_secret )

	git clone gh:jupyterhub/batchspawner
	pip install -e batchspawner/
	pip install git+https://github.com/jupyterhub/wrapspawner

	conda install notebook # only where it is being run

# 	ssd1
#	chgrp jupyterhub-daemon /export/soft/apps_el7/jupyterhub/live/jupyterhub_cookie_secret

	pip install jupyterlab
	jupyter serverextension enable --py jupyterlab --sys-prefix
#	c.Spawner.default_url = '/lab'


# 	#make user on install2
#	#adduser --user-group --no-create-home jupyterhub-daemon
#	#make -C /var/yp


KERNEL_PREFIX=/share/apps/jupyterhub/live/miniconda/
# The jupyter kernelspec https://jupyter-client.readthedocs.io/en/stable/kernels.html

# MUST load proper miniconda first!
kernels:
	jupyter kernelspec list


#	# Lmod integration
#	# https://github.com/cmd-ntrf/jupyter-lmod
	pip install jupyterlmod
	jupyter nbextension install --py jupyterlmod --sys-prefix
	jupyter nbextension enable jupyterlmod --py --sys-prefix
	jupyter serverextension enable --py jupyterlmod --sys-prefix

#	# javascript extensions
	pip install jupyter_contrib_nbextensions
	jupyter contrib nbextension install --sys-prefix
#	#jupyter nbextension enable [...name...]
	jupyter nbextension enable varInspector/main --sys-prefix


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

#	# BASH
#	# https://github.com/takluyver/bash_kernel
	pip install bash_kernel
	python -m bash_kernel.install --sys-prefix




	jupyter kernelspec list
