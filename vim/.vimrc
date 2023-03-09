" vim:set filetype=vim:

" profile start ~/.vim/profile.log
" profile func *
" profile file *

set nocompatible               " be iMproved
filetype off                   " required!

"================================================================================
" ruler, statusline
"================================================================================
set number

"ステータスラインを常に表示
set laststatus=2
" ステータスラインの表示
set statusline=%<[%n]%m%r%h%w%{'['.(&fenc!=''?&fenc:&enc).':'.&ff}%{']'}%y

if &term =~ "screen"
  " screen Buffer 切り替えで screen にファイル名を表示
  autocmd BufEnter * if bufname("") !~ "^\[A-Za-z0-9\]*://" | silent! exe '!echo -n "kv:%\\"' | endif
endif
"================================================================================
" syntax and colors
"================================================================================
syntax enable
colorscheme desert

" We know xterm-debian is a color terminal
if &term =~ "xterm-debian" || &term =~ "xterm-xfree86" || &term =~ "xterm-256color"
 set t_Co=16
 set t_Sf=[3%dm
 set t_Sb=[4%dm
endif

"タブ文字の表示
set list
set listchars=tab:>-,trail:\

"括弧入力時の対応する括弧を表示
set showmatch

" Don't wrap words by default
set textwidth=0

set t_Co=16
set t_Sf=[3%dm
set t_Sb=[4%dm

if !has('win32')
  " 補完候補色
  hi Pmenu ctermbg=8
  hi PmenuSel ctermbg=12
  hi PmenuSbar ctermbg=0
endif

if !has('macunix')
  highlight Visual ctermbg=0
else
  highlight Visual ctermbg=8
end

highlight SpecialKey ctermbg=2
highlight MatchParen cterm=none ctermbg=15 ctermfg=0
highlight Search ctermbg=5 ctermfg=0

" highlight 上書き
autocmd VimEnter,WinEnter * highlight SpecialKey ctermbg=0
autocmd VimEnter,WinEnter * highlight PmenuSel ctermbg=12

" 不可視文字の可視化
" http://vim-users.jp/2009/07/hack40/
" http://d.hatena.ne.jp/piropiropiroshki/20100321/1269119181
autocmd Colorscheme,VimEnter,WinEnter * highlight TrailingWhitespace ctermbg=red guibg=red
autocmd Colorscheme,VimEnter,WinEnter * call matchadd('TrailingWhitespace', '\s\+$', -1)

autocmd Colorscheme,VimEnter,WinEnter * highlight ZenkakuWhitespace term=underline ctermbg=DarkGreen gui=underline guibg=DarkGray
autocmd Colorscheme,VimEnter,WinEnter * call matchadd('ZenkakuWhitespace', '　', -1)

autocmd Colorscheme,VimEnter,WinEnter * highlight BlackStar term=underline ctermbg=DarkRed guibg=DarkRed
autocmd Colorscheme,VimEnter,WinEnter * call matchadd('BlackStar', '★', -1)

"================================================================================
" tabstop and indents
"================================================================================
if has("autocmd")
  filetype plugin on
  filetype indent on
  " これらのftではインデントを無効に
  " autocmd FileType php filetype indent off
  " autocmd FileType xhtml :set indentexpr=
  autocmd FileType go setl noexpandtab
  autocmd FileType python setl autoindent
  autocmd FileType python setl smartindent cinwords=if,elif,else,for,while,try,except,finally,def,class
  autocmd FileType python setl expandtab tabstop=4 shiftwidth=4 softtabstop=4
endif

" タブ幅の設定
set expandtab
set tabstop=2
set softtabstop=2
set shiftwidth=2
set modelines=5

set smartindent
"================================================================================
" search
"================================================================================
" 検索文字列が小文字の場合は大文字小文字を区別なく検索する
set ignorecase
" 検索文字列に大文字が含まれている場合は区別して検索する
set smartcase
" 検索時に最後まで行ったら最初に戻る
set wrapscan
" 検索で色をつける
set hlsearch
" 検索文字列入力時に順次対象文字列にヒットさせない
set noincsearch
" インクリメンタル検索
set incsearch
" gh で hilight を消す
nnoremap <silent> gh :let @/=''<CR>

" 検索レジストリに入ってる文字で現在のファイルを検索し、quickfix で開く
nnoremap <unique> g/ :exec ':vimgrep /' . getreg('/') . '/j %\|cwin'<CR>
" G/ ではすべてのバッファ
" nnoremap <unique> G/ :silent exec ':cexpr "" \| :bufdo vimgrepadd /' . getreg('/') . '/j %'<CR>\|:silent cwin<CR>

" バッファから検索
function! Bgrep(word)
  cexpr '' " quickfix を空に
  silent exec ':bufdo | try | vimgrepadd ' . a:word . ' % | catch | endtry'
  silent cwin
endfunction
command! -nargs=1 Bgrep :call Bgrep(<f-args>)

" :grepで組み込みのgrepを使う
set grepprg=internal
"================================================================================
" editing
"================================================================================
" Insert モード抜けたら nopaste
autocmd InsertLeave * set nopaste

" Visualモードのpで上書きされたテキストをレジスタに入れない
vnoremap p "_c<C-r>"<ESC>

" more powerful backspacing
set backspace=indent,eol,start

" http://d.hatena.ne.jp/edvakf/20100512/1273697666
" nnoremap sc :call system("pbcopy", @")
" copy to clipboard
if has("unix") && match(system("uname"),'Darwin') != -1 " mac
  " http://www.mail-archive.com/vim-latex-devel@lists.sourceforge.net/msg00773.html
  nnoremap fc :call system("pbcopy", @")<CR>
  nnoremap fp :r! pbpaste<CR>
elseif has('win32unix') " cygwin
  nnoremap fc :call system("putclip", @")<CR>
  nnoremap fp :r! getclip<CR>
endif

" Gスクロールが遅い件の対応
" set timeoutlen=400

" C-CでESC
inoremap <C-C> <ESC>

"================================================================================
" cursor moving
"================================================================================
"表示行単位で行移動する
nnoremap j gj
nnoremap k gk
vnoremap j gj
vnoremap k gk

" カーソル移動時の全角半角の判定をうまいことやる
set ambiwidth=double

" 前回終了したカーソル行に移動
autocmd BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal g`\"" | endif
"================================================================================
" completion
"================================================================================
" 辞書ファイルからの単語補間
set complete+=k

" コマンドライン補間をシェルっぽく
set wildmode=list:longest

" Suffixes that get lower priority when doing tab completion for filenames.
" These are files we are not likely to want to edit or read.
set suffixes=.bak,~,.swp,.o,.info,.aux,.log,.dvi,.bbl,.blg,.brf,.cb,.ind,.idx,.ilg,.inx,.out,.toc

"================================================================================
" buffers
"================================================================================
" バッファが編集中でもその他のファイルを開けるように
set hidden
" 外部のエディタで編集中のファイルが変更されたら自動で読み直す
set autoread

"================================================================================
" tabs
"================================================================================
nmap tc :tabe<CR>
nmap te :tabe<Space>
nmap to :tabe<Space>
nmap tn :tabnext<CR>
nmap tp :tabNext<CR>
nmap td :tabclose<CR>

"================================================================================
" encoding
"================================================================================

" svn/git での文字エンコーディング設定
autocmd FileType svn :set fileencoding=utf-8
autocmd FileType git :set fileencoding=utf-8

"================================================================================
" backup, history
"================================================================================
set nobackup    " Don't keep a backup file
" set viminfo='50,<1000,s100,\"50 " read/write a .viminfo file, don't store more than
set viminfo='500,<10000,s1000,\"500 " read/write a .viminfo file, don't store more than
"set viminfo='50,<1000,s100,:0,n~/.vim/viminfo
set history=1000 " keep 50 lines of command line history

"================================================================================
" quickfix
"================================================================================
" QuickFix のサイズ調整,自動で抜ける
function! s:autoCloseQuickFix()
  let qllen = min([10, len(getqflist())])
  cclose
  if qllen
    execute 'cw' . qllen
    normal <C-W><C-W>
  endif
  redraw
endfunction

autocmd QuickFixCmdPost * :call s:autoCloseQuickFix()

" quickfix を閉じる
nnoremap <unique> ec :cclose<CR>

"================================================================================
" other
"================================================================================
" ファイルを開いたままファイル名を変更する
" http://vim-users.jp/2009/05/hack17/
command! -nargs=1 -complete=file Rename f <args>|call delete(expand('#'))

"================================================================================
" local setting
"================================================================================
if filereadable(expand('$HOME/.vimrc.plugins'))
  source ~/.vimrc.plugins
endif

if filereadable(expand('$HOME/.vimrc.local'))
  source ~/.vimrc.local
endif

" profile pause
" noautocmd qall!
