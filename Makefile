
default:
	echo "choose command: run"
run:
	jupyterhub -f jupyterhub_config.py
#	--Class.trait=x   for command line config

# TODO
# SSL
# move cookie secret elsewhere

setup:
	false
	ml load anaconda3
	ml load teflon
	conda create --prefix $PWD/conda python pip ipython
	source activate $PWD/conda
	conda install -c conda-forge jupyterhub
	openssl rand -hex 32 > jupyterhub_cookie_secret
	chmod go-rwx jupyterhub_cookie_secret

	git clone gh:jupyterhub/batchspawner
	pip install -e batchspawner/
	pip install git+https://github.com/jupyterhub/wrapspawner

	conda install notebook # only where it is being run

