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

create:
	@$(call nixops,create,dev-infra.nix)

deploy:
	@$(call nixops,deploy,--show-trace)

clean:
	@$(call nixops,destroy,--confirm)
	@$(call nixops,delete,--confirm)
	@rm ./state/*

info:
	@$(call nixops,list)
	@$(call nixops,info)
