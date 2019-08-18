{
    network.description = "Development Infrastructure";

    vm =
        { config, pkgs, ... }:
        let
            opsctl = pkgs.buildGoPackage rec {
                name = "opsctl-${version}";
                version = "4a7f60f614d5caa5ed8260279285b358e061dee6";

                goPackagePath = "github.com/giantswarm/opsctl";

                src = builtins.fetchGit {
                    url = "https://github.com/giantswarm/opsctl";
                    ref = "master";
                    rev = "${version}";
                };
            };
        in {
            deployment.targetEnv = "ec2";
            deployment.ec2 = {
                ebsInitialRootDiskSize = 20;
                keyPair = "dev-infra";
                privateKey = "/secrets/dev-infra.pem";
                instanceType = "t2.medium";
                region = "eu-west-2";
                securityGroups = [
                    "dev-infra"
                ];
            };
            deployment.keys = {
                "config.yaml" = {
                    text = builtins.readFile /secrets/gsctl;
                    user = "joe";
                    group = "users";
                    destDir = "/etc/joe/.config/gsctl/";
                };
                giantswarm_rsa = {
                    text = builtins.readFile /secrets/giantswarm_rsa;
                    user = "joe";
                    group = "users";
                };
                gitcredentials = {
                    text = builtins.readFile /secrets/gitcredentials;
                    user = "joe";
                    group = "users";
                };
                gpg-private = {
                    text = builtins.readFile /secrets/gpg-private;
                    user = "joe";
                    group = "users";
                };
                gpg-public = {
                    text = builtins.readFile /secrets/gpg-public;
                    user = "joe";
                    group = "users";
                };
                opsctl-github = {
                    text = builtins.readFile /secrets/opsctl-github;
                    user = "joe";
                    group = "users";
                };
                opsctl-gpg = {
                    text = builtins.readFile /secrets/opsctl-gpg;
                    user = "joe";
                    group = "users";
                };
                opsctl-opsgenie = {
                    text = builtins.readFile /secrets/opsctl-opsgenie;
                    user = "joe";
                    group = "users";
                };
                gridscale = {
                    text = builtins.readFile /secrets/gridscale;
                    user = "joe";
                    group = "users";
                };
                vultr = {
                    text = builtins.readFile /secrets/vultr;
                    user = "joe";
                    group = "users";
                };
                quay = {
                    text = builtins.readFile /secrets/quay;
                    user = "joe";
                    group = "users";
                };
            };

            environment.etc."joe/.bashrc" = {
                user = "joe";
                group = "users";
                mode = "600";
                text = ''
                    if [ -f /etc/joe/.bash_aliases ]; then
                        source /etc/joe/.bash_aliases
                    fi

                    if [ -f /etc/joe/.bash_functions ]; then
                        source /etc/joe/.bash_functions
                    fi

                    set -o vi

                    sudo chown -R joe:users /etc/joe

                    if ! pgrep --exact 'ssh-agent' > /dev/null; then
                        eval `ssh-agent -s` > /dev/null 2>&1
                        ssh-add /var/run/keys/giantswarm_rsa > /dev/null 2>&1
                    fi

                    if ! gpg --list-keys 2>&1 | grep -q 'salisbury.joseph@gmail.com'; then
                        gpg --import /var/run/keys/gpg-private > /dev/null 2>&1
                        gpg --import /var/run/keys/gpg-public > /dev/null 2>&1
                    fi

                    if ! grep -q quay.io ~/.docker/config.json; then
                        docker login quay.io \
                            --username=josephsalisbury \
                            --password=$(cat /var/run/keys/quay) > /dev/null 2>&1
                    fi

                    if [ ! -f "$HOME/go/bin/goimports" ]; then
                        go get golang.org/x/tools/cmd/goimports
                    fi

                    export GPG_TTY=$(tty)
                    export HISTIGNORE='wl'

                    export PATH="$PATH:$HOME/.bin"
                    export PATH="$PATH:$HOME/go/bin"

                    export GITHUB_TOKEN=$(cat /var/run/keys/gitcredentials | awk -F ':' '{print $3}' | awk -F '@' '{print $1}')
                    export OPSCTL_GITHUB_TOKEN=$(cat /var/run/keys/opsctl-github)
                    export OPSCTL_GPG_PASSWORD=$(cat /var/run/keys/opsctl-gpg)
                    export OPSCTL_OPSGENIE_TOKEN=$(cat /var/run/keys/opsctl-opsgenie)

                    source <(opsctl completion bash)
                    source <(kubectl completion bash)

                    export PS1="\[\e[1m\]\$(date +'%Y-%m-%d %H:%M:%S')\[\e[0m\]\n$ "
                '';
            };
            environment.etc."joe/.bash_aliases" = {
                user = "joe";
                group = "users";
                mode = "600";
                text = ''
                    alias git=hub
                    alias ls='ls -FGhl --color=auto'
                    alias wl='watch --color --differences $(fc -ln -1)'
                '';
            };
            environment.etc."joe/.bash_functions" = {
                user = "joe";
                group = "users";
                mode = "600";
                text = ''
                    function access {
                        gsctl select endpoint $1 &> /dev/null
                        if kubectl --context=giantswarm-''${@: -1} cluster-info &> /dev/null; then
                                kubectl config use-context giantswarm-''${@: -1} &> /dev/null
                                printf "\033[0;32mRe-using existing kubeconfig.\033[0m\n"
                                return 0
                        fi
                        if [ "$#" -eq 2 ]; then
                                gsctl create kubeconfig \
                                        --endpoint=$1 \
                                        --cluster=$2 \
                                        --certificate-organizations=system:masters \
                                        --ttl=1d \
                                &> /dev/null
                                if [ $? -eq 0 ]; then
                                        printf "\033[0;32mCreated tenant cluster kubeconfig.\033[0m\n"
                                else
                                        printf "\033[0;31mCould not create tenant cluster kubeconfig.\033[0m\n"
                                fi
                        fi
                        if [ "$#" -eq 1 ]; then
                                opsctl create kubeconfig \
                                        --installation=$1 \
                                &> /dev/null
                                if [ $? -eq 0 ]; then
                                        printf "\033[0;32mCreated control plane kubeconfig.\033[0m\n"
                                else
                                        printf "\033[0;31mCould not create control plane kubeconfig.\033[0m\n"
                                fi
                        fi
                    }

                    function hack {
                        local organisation=""
                        local project=""

                        if [[ ! -d ~/go ]]; then
                            mkdir -p ~/go/src/github.com
                        fi

                        directory=$(find ~/go/src/github.com/ -mindepth 2 -maxdepth 2 -type d -name $1)
                        if [[ ! -z $directory ]]; then
                            cd $directory
                            return 0
                        fi

                        if [[ "$#" -eq 2 ]]; then
                            organisation=$1
                            project=$2
                        fi

                        if [[ "$#" -eq 1 ]]; then
                            project=$1

                            if $(git ls-remote https://github.com/giantswarm/$project > /dev/null 2>&1); then
                                organisation="giantswarm"
                            fi
                            if $(git ls-remote https://github.com/JosephSalisbury/$project > /dev/null 2>&1); then
                                organisation="JosephSalisbury"
                            fi
                        fi

                        mkdir -p ~/go/src/github.com/$organisation
                        cd ~/go/src/github.com/$organisation
                        git clone --quiet https://github.com/$organisation/$project
                        cd ~/go/src/github.com/$organisation/$project
                    }

                    function password {
                        cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 64 | head -n 1
                    }
                '';
            };
            environment.etc."joe/.bin/kubectl-clear" = {
                user = "joe";
                group = "users";
                mode = "700";
                text = ''
                    #!/usr/bin/env bash

                    rm -rf ~/.kube/config
                '';
            };
            environment.etc."joe/.gitconfig" = {
                user = "joe";
                group = "users";
                mode = "600";
                text = ''
                    [alias]
                        b = branch -a
                        co = checkout
                        d = diff
                        lg = log -n 5 --pretty=tformat:'%Cblue%h%Creset %<(70,trunc)%s %Cgreen(%cr)%Creset %Cblue%an%Creset'
                        st = status --short --branch
                    [commit]
                        gpgsign = true
                        template = /etc/joe/.gittemplate
                    [core]
                        editor = vi
                    [credential]
                        helper = store --file=/run/keys/gitcredentials
                    [help]
                        autocorrect = -1
                    [pager]
                        branch = false
                        log = false
                    [url "https://github.com/"]
                        insteadOf = git@github.com:
                    [user]
                        name = Joseph Salisbury
                        email = salisbury.joseph@gmail.com
                        signingkey = 1C6A41349CB55511
                '';
            };
            environment.etc."joe/.gittemplate" = {
                user = "joe";
                group = "users";
                mode = "600";
                text = ''
                    # If this commit is applied, then it (e.g: Removes the foo)

                    # Towards this issue

                    # And this is _why_ we did it

                '';
            };
            environment.etc."joe/.gnupg/gpg.conf" = {
                user = "joe";
                group = "users";
                mode = "600";
                text = ''
                    trusted-key 1C6A41349CB55511
                '';
            };
            environment.etc."joe/.profile" = {
                user = "joe";
                group = "users";
                mode = "600";
                text = ''
                    if [ -n "$BASH_VERSION" ]; then
                        if [ -f "$HOME/.bashrc" ]; then
                            . "$HOME/.bashrc"
                        fi
                    fi
                '';
            };
            environment.etc."joe/.tmux.conf" = {
                user = "joe";
                group = "users";
                mode = "600";
                text = ''
                    bind r source-file /etc/joe/.tmux.conf
                    set -g base-index 1
                    set -g default-terminal "screen-256color"
                    set -g pane-base-index 1
                    set -g status-bg colour7
                    set -g status-fg colour232
                    set -g status-interval 1
                    set -g status-left ""
                    set -g window-status-format "#I"
                    set -g window-status-current-format "#I#F"
                    set -g status-right "#(/etc/joe/.tmux-status.sh)"
                    set -g status-right-length 500
                '';
            };
            environment.etc."joe/.tmux-status.sh" = {
                user = "joe";
                group = "users";
                mode = "700";
                text = ''
                    #!/bin/sh

                    path="$(tmux display-message -p -F "#{pane_current_path}")"
                    git_branch=$(cd $path; git rev-parse --abbrev-ref HEAD 2> /dev/null)
                    kubectl_context=$(kubectl config current-context | sed -e 's/giantswarm-//')

                    if [ $path == $HOME ]; then
                        path_info="~"
                    else
                        path_info="$(basename $path)"
                    fi
                    git_info=""
                    if [ ! -z "$git_branch" ]; then
                      git_info=" ($git_branch)"
                    fi
                    kube_info=""
                    if [ ! -z "$kubectl_context" ]; then
                      kube_info=" ($kubectl_context)"
                    fi

                    echo $path_info$git_info$kube_info
                '';
            };
            environment.etc."joe/.vimrc" = {
                user = "joe";
                group = "users";
                mode = "600";
                text = ''
                    set autoread

                    au BufWritePost *.go !goimports -w %
                '';
            };

            environment.noXlibs = true;

            environment.systemPackages = with pkgs; [
                bind
                git
                gitAndTools.hub
                gnumake
                gnupg
                go
                gsctl
                htop
                jq
                kubectl
                opsctl
                python3
                tmux
                tree
                vim
                wget
                yq
            ];

            networking.hostName = "vm";

            programs.mosh.enable = true;
            programs.vim.defaultEditor = true;

            security.sudo.wheelNeedsPassword = false;

            services.openvpn.servers = {
                gridscale = {
                    config = "config /var/run/keys/gridscale";
                    updateResolvConf = true;
                };
                vultr = {
                    config = "config /var/run/keys/vultr";
                    updateResolvConf = true;
                };
            };

            system.autoUpgrade = {
                channel = "https://nixos.org/channels/nixos-19.03";
                enable = true;
            };

            time.timeZone = "Europe/London";

            users.mutableUsers = false;
            users.users.joe = {
                isNormalUser = true;
                home = "/etc/joe";
                description = "Joe Salisbury";
                extraGroups = [
                    "docker"
                    "keys"
                    "wheel"
                ];
                openssh.authorizedKeys.keys = [
                    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDbANMu71iyqQ9HgVC+UF4OPXcPE0BL23B9/w/2b5Yjvhboc1z+G0ElP8MtPp55zw8Gt6Xl7nuK4SL8pBJxVlLriop1+41lcM+hBHIBW5JsZO7ygPApvXoF3855o2jkZpVgOTAuIlNF+edvWEi1u4DoODtl5u/NXvLg18lZrt8e+QOxQsxPixX+rkoA5p5jOJIsyUsPn+68HJlWsxEh9QClGvx1gx1lq+yRamz8pJdF11k19m/FvwIVnnhM9ZhFvtADJ89d6mEb6BQI0mZ2Nl+uGAd9D8k0aBmvpsUxb+DzTOfLXRl3SHVXR/W7qokSCoKDjnff6Oy3Pm0ly6DVMjSr"
                ];
            };

            virtualisation.docker.enable = true;
        };
}
