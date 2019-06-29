.PHONY: create deploy clean info

define nixops
	docker run --rm \
		-v $$(pwd)/infra/dev-infra.nix:/dev-infra.nix \
		-v $$(pwd)/state:/state \
		-v $$(pwd)/secrets:/secrets \
		-e EC2_ACCESS_KEY=$$(cat ./credentials/access-key-id) \
		-e EC2_SECRET_KEY=$$(cat ./credentials/secret-access-key) \
		-e NIXOPS_STATE=/state/deployments.nixops \
		-e NIXOPS_DEPLOYMENT=dev-infra \
		quay.io/josephsalisbury/nixops \
		$1 $2 $3
endef

define s3
	docker run --rm \
		-v $$(pwd):/repo \
		-e AWS_ACCESS_KEY_ID=$$(cat ./credentials/access-key-id) \
		-e AWS_SECRET_ACCESS_KEY=$$(cat ./credentials/secret-access-key) \
		-e AWS_DEFAULT_REGION=eu-west-2 \
		mesosphere/aws-cli:1.14.5 \
		s3 $1 $2 $3
endef

define encrypt
	tar \
		-czf \
		$1.tar.gz \
		$1
	gpg \
		--output $2 \
		--passphrase $$(cat ./credentials/pgp-passphrase) \
		--batch \
		--symmetric \
		$1.tar.gz
	rm $1.tar.gz
endef

define decrypt
	gpg \
		--output $1.tar.gz \
		--passphrase $$(cat ./credentials/pgp-passphrase) \
		--quiet \
		--batch \
		--decrypt \
		$1
	tar \
		-xzf \
		$1.tar.gz
	rm $1.tar.gz
endef

define upload
	$(call s3,cp,/repo/$1,s3://shi-dev-infra/$1)
endef

define download
	$(call s3,cp,s3://shi-dev-infra/$1,/repo/$1)
endef



create:
	$(call nixops,create,dev-infra.nix)

deploy:
	$(call nixops,deploy,--show-trace)

clean:
	$(call nixops,destroy,--confirm)
	$(call nixops,delete,--confirm)
	rm ./state/*

info:
	$(call nixops,list)
	$(call nixops,info)



encrypt-state:
	$(call encrypt,./state,./state.enc)

decrypt-state:
	$(call decrypt,./state.enc)

upload-state:
	$(call upload,state.enc)

download-state:
	$(call download,state.enc)



encrypt-secrets:
	$(call encrypt,./secrets,./secrets.enc)

decrypt-secrets:
	$(call decrypt,./secrets.enc)

upload-secrets:
	$(call upload,secrets.enc)

download-secrets:
	$(call download,secrets.enc)



crypto-clean:
	rm -f ./state.tar.gz
	rm -f ./state.enc
	rm -f ./secrets.tar.gz
	rm -f ./secrets.enc
