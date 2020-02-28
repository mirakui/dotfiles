dotfiles-vim
============

## Install
```
$ git clone https://github.com/mirakui/dotfiles-vim.git
$ cd dotfiles-vim
$ git submodule update -i
$ cd .vim/bundle/vimproc; make; cd -
$ ln -s `pwd`/{.vim,.vimrc,.vimrc.plugins} ~/
$ vim -c ':NeoBundleInstall'
```
