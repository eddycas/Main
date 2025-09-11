# ~/.bashrc

# Set colored prompt: username@hostname in green
PS1="\[\e[32m\]\u@\h:\w\$ \[\e[0m\]"

# Enable colored output for 'ls' and other commands
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'

# Add Flutter to PATH (update the path if Flutter is installed somewhere else)
export PATH="$HOME/.flutter/bin:$PATH"

# Source global definitions (optional)
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi
export PATH="$HOME/flutter/bin:$PATH"
