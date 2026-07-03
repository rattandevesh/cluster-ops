.PHONY: install-tools create upgrade destroy addons argocd

install-tools:
	ansible-playbook install-tools.yml

create:
	ansible-playbook cluster-create.yml

upgrade:
	ansible-playbook cluster-upgrade.yml

destroy:
	ansible-playbook cluster-destroy.yml

addons:
	ansible-playbook addons-bootstrap.yml

argocd:
	ansible-playbook argocd-install.yml

deps:
	ansible-galaxy collection install -r requirements.yml
