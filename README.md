# Inference backends

Scripts to launch and manage various inference backends.

```bash
sudo apt update
sudo apt install -y lolcat figlet
```

```bash
figlet $(hostname) | lolcat
```


```bash
#sudo apt install -y fzf
# https://github.com/ajeetdsouza/zoxide?tab=readme-ov-file#installation
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
# in your shell:
PATH="$PATH:$HOME/.local/bin"
eval "$(zoxide init bash)"
#eval "$(fzf --bash)"
https://github.com/junegunn/fzf/tree/v0.55.0?tab=readme-ov-file#linux-packages
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
alias cd="z"
#fzf --version
```
