FROM ghcr.io/void-linux/void-linux:20210220rc01-full-x86_64-musl

USER root
# FIXME: Ignore cert errors, not secure but SSL errors happen in gitpod testing.
ENV SSL_NO_VERIFY_PEER=1
# Make sure we have the latest xbps, refuses to fetch packages otherwise
RUN xbps-install -Myu xbps \
# Update packages, I know this isn't docker best practice, but void is a rolling release
    && xbps-install -Myu \
# Install gitpod/workspace-go-c-vnc equivalent packages
    && xbps-install -My docker docker-compose vscode tigervnc llvm12 gcc-fortran go git git-lfs sudo p7zip htop jq curl less chromium python3-pip python3-Cython python3-devel openblas-devel lapack-devel cblas-devel noto-fonts-ttf noto-fonts-cjk noto-fonts-emoji bash-completion \
# Install my preferred environment
    && xbps-install -My cwm xterm dte

# Setup gitpod user
RUN useradd -l -u 33333 -G wheel -md /home/gitpod -s /bin/bash -p gitpod gitpod \
    && echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' >> /etc/sudoers \
    && mkdir /workspace && chown -hR gitpod:gitpod /workspace
ENV HOME=/home/gitpod
WORKDIR $HOME

COPY .gitpod-utils/default.gitconfig /etc/gitconfig
COPY --chown=gitpod:gitpod .gitpod-utils/default.gitconfig /home/gitpod/.gitconfig

# configure git-lfs
RUN git lfs install --system --skip-repo

# Install noVNC
RUN git clone --depth 1 https://github.com/novnc/noVNC.git /opt/novnc \
	&& git clone --depth 1 https://github.com/novnc/websockify /opt/novnc/utils/websockify \
	&& find /opt/novnc -type d -name '.git' -exec rm -rf '{}' + \
	&& sudo -H pip3 install numpy
COPY .gitpod-utils/novnc-index.html /opt/novnc/index.html
# Add VNC startup script
# FIXME: gp-vncsession needs to be voided
# COPY .gitpod-utils/gp-vncsession /usr/bin/
# RUN chmod 0755 "$(which gp-vncsession)" \
# 	&& printf '%s\n' 'export DISPLAY=:0' \
# 	'test -e "$GITPOD_REPO_ROOT" && gp-vncsession' >> "$HOME/.bashrc"
# Add X11 dotfiles
COPY --chown=gitpod:gitpod .gitpod-utils/.xinitrc $HOME/

RUN rm -rf /var/cache/xbps

USER gitpod

# use sudo so that user does not get sudo usage info on (the first) login
RUN sudo echo "Running 'sudo' for Gitpod: success" && \
    # create .bashrc.d folder and source it in the bashrc
    mkdir -p /home/gitpod/.bashrc.d && \
    (echo; echo "for i in \$(ls -A \$HOME/.bashrc.d/); do source \$HOME/.bashrc.d/\$i; done"; echo) >> /home/gitpod/.bashrc && \
    # create a completions dir for gitpod user
    mkdir -p /home/gitpod/.local/share/bash-completion/completions \
    && curl -o /home/gitpod/.git-prompt.sh https://raw.githubusercontent.com/git/git/master/contrib/completion/git-prompt.sh \
    && echo "source /home/gitpod/.git-prompt.sh" >> .bashrc \
# custom Bash prompt
    && { echo && echo "PS1='\[\033[01;32m\]\u\[\033[00m\] \[\033[01;34m\]\w\[\033[00m\]\$(__git_ps1 \" (%s)\") $ '" ; } >> .bashrc

# Custom PATH additions
ENV PATH=$HOME/.local/bin:/usr/games:$PATH

# Configure go
ENV GOPATH=$HOME/go
ENV GOROOT=/usr/lib/go
ENV PATH=$GOROOT/bin:$GOPATH/bin:$PATH
RUN mkdir -p $GOPATH && \
    go install -v github.com/uudashr/gopkgs/cmd/gopkgs@v2 && \
    go install -v github.com/ramya-rao-a/go-outline@latest && \
    go install -v github.com/cweill/gotests/gotests@latest && \
    go install -v github.com/fatih/gomodifytags@latest && \
    go install -v github.com/josharian/impl@latest && \
    go install -v github.com/haya14busa/goplay/cmd/goplay@latest && \
    go install -v github.com/go-delve/delve/cmd/dlv@latest && \
    go install -v github.com/golangci/golangci-lint/cmd/golangci-lint@latest && \
    go install -v golang.org/x/tools/gopls@latest && \
    sudo rm -rf $GOPATH/src $GOPATH/pkg $HOME/.cache/go $HOME/.cache/go-build && \
    printf '%s\n' 'export GOPATH=/workspace/go' \
                  'export PATH=$GOPATH/bin:$PATH' > $HOME/.bashrc.d/300-go