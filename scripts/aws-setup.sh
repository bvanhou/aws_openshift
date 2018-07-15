#!/bin/bash

if [ $( curl --connect-timeout 2 -s -L https://ec2.us-east-1.amazonaws.com | wc -l ) -lt 10 ] ; then
	echo Unable to connect to AWS. Please check proxy configuration.
	exit 1
fi

export PYTHONPATH=$HOME/.local

mkdir -p $PYTHONPATH/lib/python2.7/site-packages

easy_install --install-dir $PYTHONPATH boto boto3 awscli

mkdir -p $HOME/bin

curl -s https://raw.githubusercontent.com/ansible/ansible/devel/contrib/inventory/ec2.py -o $HOME/bin/ec2.py

cat <<_END_ > $HOME/bin/ec2.sh
#!/bin/bash --

MYDIR=\$(dirname \$0)

[ -z "\$EC2_INI_PATH" -a -s "\$PWD/ec2.ini" ] && export EC2_INI_PATH=\$PWD/ec2.ini

export PYTHONPATH=\$HOME/.local
export https_proxy=$https_proxy
export http_proxy=$http_proxy
unset no_proxy

exec \$MYDIR/ec2.py \$@
_END_

cat <<_END_ > $HOME/bin/aws
#!/bin/bash

export PYTHONPATH=\$HOME/.local
export https_proxy=$https_proxy

exec \$PYTHONPATH/aws \$@
_END_
chmod +x $HOME/bin/aws $HOME/bin/ec2.sh $HOME/bin/ec2.py

grep -sq 'aws_completer' $HOME/.bash_profile || \
	cat <<'_END_' >> $HOME/.bash_profile
export PATH=$home/bin:$PATH
export PYTHONPATH=$HOME/.local:$PYTHONPATH

[ -s $HOME/.local/aws_completer ] && \
        complete -C \$HOME/.local/aws_completer aws
_END_

echo Now reload your Bash profile

exit 0
