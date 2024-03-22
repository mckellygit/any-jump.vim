" TODO_RELEASE:
" - sync file types comments
" - sync file types
" - add custom lang with hot patches (no el files required) - for viml
" - remove emacs regexp for compaction

" TODO:
" - wrap for nvim should be configurable
" - [more] button should append N items only on current collection
" - add scope :symbol to ruby syntax
" - add mouse-click evets support
" - any-jump-last should also restore cursor position
" - add definitions rules for rails meta expressions in ruby like `has_many :users`
" - hl keyword in result line also
" - ability to jumps and lookups for library source codes paths
" - [hot] display type of definition
" - [option] cut long lines
" - guide on how to add language
" - AnyJumpFirst - if found result from prefered dirs of only one result
"   then jump to it, othrewise open ui
" - [option] auto preview first result
"
" UI:
" - add rerun search button (first step to refuctoring) (first `R` - rerun
"   search and just show diff only; `RR` -> rerun search and show new results)
"
" TODO_THINK:
" - after pressing p jump to next result
" - fzf
" - ability to scroll preview
" - [vim] может стоит перепрыгивать пустые строки? при j/k
" - support for old vims via opening buffer in split (?)
"
" WILL_NEVER:
" - fzf or quickfix, because any-jump ui is some sort of qf
"   but if you wish to provide any-jump definitions/references search results
"   to fzf or quickfix please create pull request with this core modification.
"
" TODO_FUTURE_RELEASES:
" - [nvim] >> Once a focus to the floating window is lost, the window should disappear. Like many other plugins with floating window.
"   add auto-hide option?
"
" - AnyJumpPreview
" - "save jump" button ??
" - jumps list ?? (AnyJumps)

" === Vim version check
let s:nvim = has('nvim')

fu! s:host_vim_errors() abort
  let errors = []

  if s:nvim
    if !exists('*nvim_open_win')
      call add(errors, "nvim_open_win support required")
    endif
  else
    if !exists('*popup_menu')
      call add(errors, "popup_menu support required")
    endif
  endif

  return errors
endfu

let errors = s:host_vim_errors()

if len(errors)
  echoe "any-jump can't be loaded: " . join(errors, ', ')
  finish
endif

" === Plugin options ===

fu! s:set_plugin_global_option(option_name, default_value) abort
  if !exists('g:' .  a:option_name)
    let g:{a:option_name} = a:default_value
  endif
endfu

" Cursor keyword selection mode
"
" on line:
"
" "MyNamespace::MyClass"
"                  ^
"
" then cursor is on MyClass word
"
" 'word' - will match 'MyClass'
" 'full' - will match 'MyNamespace::MyClass'

call s:set_plugin_global_option('any_jump_keyword_match_cursor_mode', 'word')

" Ungrouped results ui variants:
" - 'filename_first'
" - 'filename_last'
call s:set_plugin_global_option('any_jump_results_ui_style', 'filename_first')

" Show line numbers in search rusults
call s:set_plugin_global_option('any_jump_list_numbers', v:false)

" Auto search usages
call s:set_plugin_global_option('any_jump_references_enabled', v:true)

" Auto group results by filename
call s:set_plugin_global_option('any_jump_grouping_enabled', v:false)

" Amount of preview lines for each search result
call s:set_plugin_global_option('any_jump_preview_lines_count', 5)

" Max search results, other results can be opened via [a]
call s:set_plugin_global_option('any_jump_max_search_results', 10)

" Prefered search engine: rg or ag
call s:set_plugin_global_option('any_jump_search_prefered_engine', 'rg')

" Disable default keybindinngs for commands
call s:set_plugin_global_option('any_jump_disable_default_keybindings', v:false)

" Any-jump window size & position options
call s:set_plugin_global_option('any_jump_window_width_ratio', str2float('0.6'))
call s:set_plugin_global_option('any_jump_window_height_ratio', str2float('0.6'))
call s:set_plugin_global_option('any_jump_window_top_offset', 2)

" Remove comments line from search results (default: 1)
call s:set_plugin_global_option('any_jump_remove_comments_from_results', v:true)

" Search references only for current file type
" (default: false, so will find keyword in all filetypes)
call s:set_plugin_global_option('any_jump_references_only_for_current_filetype', v:false)

" Disable search engine ignore vcs untracked files (default: false, search engine will ignore vcs untracked files)
call s:set_plugin_global_option('any_jump_disable_vcs_ignore', v:false)

" Custom ignore files
" default is: ['*.tmp', '*.temp']
call s:set_plugin_global_option('any_jump_ignored_files', ['*.tmp', '*.temp'])

" ----------------------------------------------
" Public customization methods
" ----------------------------------------------

let s:default_colors = {
      \"plain_text": "Comment",
      \"preview": 'Comment',
      \"preview_keyword": "Operator",
      \"heading_text": "Function",
      \"heading_keyword": "Identifier",
      \"group_text": "Comment",
      \"group_name": "Function",
      \"more_button": "Operator",
      \"more_explain": "Comment",
      \"result_line_number": "Comment",
      \"result_text": "Statement",
      \"result_path": "String",
      \"help": "Comment"
      \}

let g:any_jump_colors_compiled = s:default_colors

if exists('g:any_jump_colors')
  call extend(g:any_jump_colors_compiled, g:any_jump_colors)
endif

" TODO: change to private# api
fu! g:AnyJumpGetColor(name) abort
  if has_key(g:any_jump_colors_compiled, a:name)
    return g:any_jump_colors_compiled[a:name]
  else
    echo "any-jump color not found: " . a:name
    return 'Comment'
  endif
endfu

" NOTE: use same <Leader>r: (and also <Leader>a:) to set g:rtagsUseColonKeyword here
if !exists("g:rtagsUseColonKeyword")
    let g:rtagsUseColonKeyword = 0
endif

" ----------------------------------------------
" Functions
" ----------------------------------------------

fu! s:CreateUi(internal_buffer) abort

  " before creating a new lookup buffer check if
  " another already exists and if so remove it ...
  let aj = []
  let cnt = 0
  for b in getbufinfo()
    if !b.listed
      if b.name =~ 'any-jump lookup '
        call add(aj, b.bufnr)
        let cnt = cnt + 1
      endif
    endif
  endfor
  if cnt > 1
    let oldest = min(aj)
    execute "bwipe! " . oldest
  endif
  " --------------------------------------------

  if s:nvim
    call s:CreateNvimUi(a:internal_buffer)
  else
    call s:CreateVimUi(a:internal_buffer)
  endif
endfu

fu! s:CreateNvimUi(internal_buffer) abort
  let kw  = a:internal_buffer.keyword
  let buf = nvim_create_buf(1, 0)
  call nvim_buf_set_name(buf, 'any-jump lookup ' . kw)

  call nvim_buf_set_option(buf, 'bufhidden', 'delete')
  call nvim_buf_set_option(buf, 'buftype', 'nofile')
  call nvim_buf_set_option(buf, 'modifiable', v:true)

  let height     = float2nr(&lines * g:any_jump_window_height_ratio)
  let width      = float2nr(&columns * g:any_jump_window_width_ratio)
  let horizontal = float2nr((&columns - width) / 2)
  if g:any_jump_window_top_offset >= 0
    let vertical   = g:any_jump_window_top_offset
  else
    let vertical   = float2nr((&lines - height) / 2)
  endif

  let opts = {
        \ 'relative': 'editor',
        \ 'row': vertical,
        \ 'col': horizontal,
        \ 'width': width,
        \ 'height': height,
        \ 'style': 'minimal',
        \ 'border': 'single',
        \ }

  let winid = nvim_open_win(buf, v:true, opts)

  " Set filetype after window appearance for proper event propagation
  call nvim_buf_set_option(buf, 'filetype', 'any-jump')

  call nvim_win_set_option(winid, 'number', v:false)
  call nvim_win_set_option(winid, 'wrap', v:true)
  call nvim_win_set_option(winid, 'cursorline', v:true)

  let t:any_jump.vim_bufnr = buf

  call t:any_jump.RenderUi()
  call t:any_jump.JumpToFirstOfType('link', 'definitions')
endfu

function! s:PopupClosed(id, result)
  if a:result == -1
    "echo "Popup closed from <C-c>"
  endif
endfunction

fu! s:CreateVimUi(internal_buffer) abort
  let l:Filter   = function("s:VimPopupFilter")

  let height = float2nr(&lines * g:any_jump_window_height_ratio)
  let width  = float2nr(&columns * g:any_jump_window_width_ratio)

  let popup_winid = popup_menu([], {
        \"wrap":       1,
        \"cursorline": 1,
        \"minheight":  height,
        \"maxheight":  height,
        \"minwidth":   width,
        \"maxwidth":   width,
        \"scrollbar":  0,
        \"border":     [],
        \"borderchars":['─', '│', '─', '│', '┌', '┐', '┘', '└'],
        \"padding":    [0,1,1,1],
        \"filter":     Filter,
        \"callback":   function("s:PopupClosed"),
        \})

  let a:internal_buffer.popup_winid = popup_winid
  let a:internal_buffer.vim_bufnr   = winbufnr(popup_winid)

  call a:internal_buffer.RenderUi()
  if !has("nvim")
    " mck - dont jump here
    "call a:internal_buffer.JumpToFirstOfType('link', 'definitions')
    call popup_filter_menu(popup_winid, "j")
  endif
endfu

fu! s:VimPopupFilter(popup_winid, key) abort
  let bufnr = winbufnr(a:popup_winid)
  let ib    = s:GetCurrentInternalBuffer()

  " ---------------

  if a:key ==# "k"
    call popup_filter_menu(a:popup_winid, a:key)
    return 1

  elseif a:key == "\<Up>"
    call popup_filter_menu(a:popup_winid, "k")
    return 1

  elseif a:key == "\<M-k>"
    call win_execute(a:popup_winid, "silent normal! 5k")
    return 1

  elseif a:key == "\<F30>" "<M-k>
    call win_execute(a:popup_winid, "silent normal! 5k")
    return 1

  elseif a:key ==# "K"
    call win_execute(a:popup_winid, "silent normal! \<C-y>k")
    return 1

  elseif a:key == "\<M-K>"
    call win_execute(a:popup_winid, "silent normal! \<C-y>k")
    return 1

  elseif a:key == "\<F26>" "<M-S-k>
    call win_execute(a:popup_winid, "silent normal! \<C-y>k")
    return 1

  elseif a:key == "\<C-k>"
    call win_execute(a:popup_winid, "silent normal! \<C-y>k")
    return 1

  elseif a:key == "\<C-Up>"
    call win_execute(a:popup_winid, "silent normal! \<C-y>k")
    return 1

  elseif a:key == "\<M-Up>"
    call win_execute(a:popup_winid, "silent normal! \<C-y>k")
    return 1

  elseif a:key == "\<M-C-K>"
    call win_execute(a:popup_winid, "silent normal! 5\<C-y>5k")
    return 1

  elseif a:key == "\<F28>" "<M-C-k>
    call win_execute(a:popup_winid, "silent normal! 5\<C-y>5k")
    return 1

  elseif a:key == "\<M-BS>"
    call win_execute(a:popup_winid, "silent normal! \<C-y>k")
    return 1

  elseif a:key == "\<S-F30>" "<M-BS>
    call win_execute(a:popup_winid, "silent normal! \<C-y>k")
    return 1

  elseif a:key == "\<BS>"
    call win_execute(a:popup_winid, "silent normal! 5\<C-y>5k")
    return 1

  elseif a:key == "\<C-b>"
    call win_execute(a:popup_winid, "silent normal! 5\<C-y>5k")
    return 1

  elseif a:key == "\<C-u>"
    call win_execute(a:popup_winid, "silent normal! 5\<C-y>5k")
    return 1

  elseif a:key == "\<PageUp>"
    call win_execute(a:popup_winid, "silent normal! 5\<C-y>5k")
    return 1

  elseif a:key == "\<C-PageUp>"
    call win_execute(a:popup_winid, "silent normal! 5\<C-y>5k")
    return 1

  elseif a:key == "\<C-PageUp>"
    call win_execute(a:popup_winid, "silent normal! 5\<C-y>5k")
    return 1

  elseif a:key == "\<S-F21>" "<C-PageUp>
    call win_execute(a:popup_winid, "silent normal! 5\<C-y>5k")
    return 1

  elseif a:key == "\<M-PageUp>"
    call win_execute(a:popup_winid, "silent normal! 5\<C-y>5k")
    return 1

  elseif a:key == "\<S-F23>" "<M-PageUp>
    call win_execute(a:popup_winid, "silent normal! 5\<C-y>5k")
    return 1

  elseif a:key == "\<C-S-PageUp>"
    call win_execute(a:popup_winid, "silent normal! 5\<C-y>5k")
    return 1

  elseif a:key == "\<S-F22>" "<C-S-PageUp>
    call win_execute(a:popup_winid, "silent normal! 5\<C-y>5k")
    return 1

  elseif a:key == "\<S-PageUp>"
    call win_execute(a:popup_winid, "silent normal! \<C-y>k")
    return 1

  elseif a:key == "\<S-F17>" "<S-PageUp>
    call win_execute(a:popup_winid, "silent normal! \<C-y>k")
    return 1

  elseif a:key == "\<M-S-PageUp>"
    call win_execute(a:popup_winid, "silent normal! 5\<C-y>5k")
    return 1

  elseif a:key == "\<S-F19>" "<M-S-PageUp>
    call win_execute(a:popup_winid, "silent normal! 5\<C-y>5k")
    return 1

  " ---------------

  elseif a:key ==# "j"
    call popup_filter_menu(a:popup_winid, a:key)
    return 1

  elseif a:key == "\<Down>"
    call popup_filter_menu(a:popup_winid, "j")
    return 1

  elseif a:key == "\<M-j>"
    call win_execute(a:popup_winid, "silent normal! 5j")
    return 1

  elseif a:key == "\<F31>" "<M-j>
    call win_execute(a:popup_winid, "silent normal! 5j")
    return 1

  elseif a:key ==# "J"
    call win_execute(a:popup_winid, "silent normal! \<C-e>j")
    return 1

  elseif a:key == "\<M-J>"
    call win_execute(a:popup_winid, "silent normal! \<C-e>j")
    return 1

  elseif a:key == "\<F23>" "<M-S-j>
    call win_execute(a:popup_winid, "silent normal! \<C-e>j")
    return 1

  elseif a:key == "\<C-j>"
    call win_execute(a:popup_winid, "silent normal! \<C-e>j")
    return 1

  elseif a:key == "\<C-Down>"
    call win_execute(a:popup_winid, "silent normal! \<C-e>j")
    return 1

  elseif a:key == "\<M-Down>"
    call win_execute(a:popup_winid, "silent normal! \<C-e>j")
    return 1

  elseif a:key == "\<M-C-O>" "(subst for <M-C-j> ...)
    call win_execute(a:popup_winid, "silent normal! 5\<C-e>5j")
    return 1

  elseif a:key == "\<F29>" "<M-C-o> (subst for <M-C-j> ...)
    call win_execute(a:popup_winid, "silent normal! 5\<C-e>5j")
    return 1

  elseif a:key == "\<M-Space>"
    call win_execute(a:popup_winid, "silent normal! \<C-e>j")
    return 1

  elseif a:key == "\<S-F29>" "<M-Space>
    call win_execute(a:popup_winid, "silent normal! \<C-e>j")
    return 1

  elseif a:key == "\<Space>"
    call win_execute(a:popup_winid, "silent normal! 5\<C-e>5j")
    return 1

  elseif a:key == "\<C-f>"
    call win_execute(a:popup_winid, "silent normal! 5\<C-e>5j")
    return 1

  elseif a:key == "\<C-d>"
    call win_execute(a:popup_winid, "silent normal! 5\<C-e>5j")
    return 1

  elseif a:key == "\<PageDown>"
    call win_execute(a:popup_winid, "silent normal! 5\<C-e>5j")
    return 1

  elseif a:key == "\<C-PageDown>"
    call win_execute(a:popup_winid, "silent normal! 5\<C-e>5j")
    return 1

  elseif a:key == "\<S-F24>" "<C-PageDown>
    call win_execute(a:popup_winid, "silent normal! 5\<C-e>5j")
    return 1

  elseif a:key == "\<M-PageDown>"
    call win_execute(a:popup_winid, "silent normal! 5\<C-e>5j")
    return 1

  elseif a:key == "\<S-F26>" "<M-PageDown>
    call win_execute(a:popup_winid, "silent normal! 5\<C-e>5j")
    return 1

  elseif a:key == "\<C-S-PageDown>"
    call win_execute(a:popup_winid, "silent normal! 5\<C-e>5j")
    return 1

  elseif a:key == "\<S-F25>" "<C-S-PageDown>
    call win_execute(a:popup_winid, "silent normal! 5\<C-e>5j")
    return 1

  elseif a:key == "\<S-PageDown>"
    call win_execute(a:popup_winid, "silent normal! \<C-e>j")
    return 1

  elseif a:key == "\<S-F18>" "<S-PageDown>
    call win_execute(a:popup_winid, "silent normal! \<C-e>j")
    return 1

  elseif a:key == "\<M-S-PageDown>"
    call win_execute(a:popup_winid, "silent normal! 5\<C-e>5j")
    return 1

  elseif a:key == "\<S-F20>" "<M-S-PageDown>
    call win_execute(a:popup_winid, "silent normal! 5\<C-e>5j")
    return 1

  " ---------------

  " horizontal scroll - is it possible in vim popup ??

  elseif a:key == "\<S-Right>"
    call win_execute(a:popup_winid, "silent normal! 10zl10l")
    return 1

  elseif a:key == "\<S-Left>"
    call win_execute(a:popup_winid, "silent normal! 10zh10h")
    return 1

  elseif a:key == "\<M-l>"
    call win_execute(a:popup_winid, "silent normal! 10zl10l")
    return 1

  elseif a:key == "\<M-h>"
    call win_execute(a:popup_winid, "silent normal! 10zh10h")
    return 1

  elseif a:key == "\<M-.>"
    call win_execute(a:popup_winid, "silent normal! 10zl10l")
    return 1

  elseif a:key == "\<M-h>"
    call win_execute(a:popup_winid, "silent normal! 10zh10h")
    return 1

  " ---------------

  " cannot do 2-char popup filter input for gg ...

  elseif a:key == "\<C-Home>"
    call win_execute(a:popup_winid, "silent normal! gg")
    return 1

  elseif a:key == "\<C-End>"
    call win_execute(a:popup_winid, "silent normal! G")
    return 1

  " ---------------

  elseif a:key == "\<M-C-P>"
    call g:AnyJumpHandlePreview()
    return 1

  elseif a:key == "\<S-F27>" "<M-C-p>
    call g:AnyJumpHandlePreview()
    return 1

  " ---------------

  elseif a:key == "p" || a:key == "\<TAB>"
    call g:AnyJumpHandlePreview()
    return 1

  elseif a:key ==# "a"
    call g:AnyJumpLoadNextBatchResults()
    return 1

  elseif a:key ==# "A"
    call g:AnyJumpToggleAllResults()
    return 1

  elseif a:key ==# "r"
    call g:AnyJumpHandleReferences()
    return 1

  elseif a:key ==# "T"
    call g:AnyJumpToggleGrouping()
    return 1

  elseif a:key ==# "L"
    call g:AnyJumpToggleListStyle()
    return 1

  elseif a:key ==# 'b'
    call g:AnyJumpToFirstLink()
    return 1

  elseif a:key ==# "0"
    call g:AnyJumpToFirstLink()
    return 1

  elseif a:key == "\<CR>" || a:key == 'o'
    call g:AnyJumpHandleOpen()
    return 1

  elseif a:key ==# "t"
    call g:AnyJumpHandleOpen('tab')
    return 1

  elseif a:key ==# "\<C-t>"
    call g:AnyJumpHandleOpen('tab')
    return 1

  " cannot use multi-char <C-t>t, <C-t><C-t> here ...

  elseif a:key ==# "s"
    call g:AnyJumpHandleOpen('split')
    return 1

  elseif a:key ==# "\<C-x>"
    call g:AnyJumpHandleOpen('split')
    return 1

  elseif a:key ==# "v"
    call g:AnyJumpHandleOpen('vsplit')
    return 1

  elseif a:key ==# "\<C-v>"
    call g:AnyJumpHandleOpen('vsplit')
    return 1

  elseif a:key ==# "q"
        \ || a:key ==# "x"
        \ || a:key ==# "\<C-q>"
        \ || a:key ==# "\<F18>"
        \ || a:key ==# "\<C-c>"
    " TODO: skip <Esc> ?
    " close from <C-c> cannot be caught here, but can be handled in s:PopupClosed()
    call g:AnyJumpHandleClose()
    return 1
  endif

  return 1
endfu

fu! s:GetCurrentInternalBuffer() abort
  if exists('t:any_jump')
    return t:any_jump
  else
    throw "any-jump internal buffer lost"
  endif
endfu

fu! s:Jump(...) abort range
  redraw!
  echo " "

  " if called from an any-jump window then ignore ...
  let bname = bufname('%')
  if bname =~ 'any-jump lookup '
    return
  endif

  let lang = lang_map#get_language_from_filetype(&l:filetype)
  let keyword = ''
  let search_meth = 'gr'

  let opts = {}
  if a:0
    let opts = a:1
  endif

  let has_kw = 0
  if has_key(opts, 'is_visual')
    let x = getpos("'<")[2]
    let y = getpos("'>")[2]
    let keyword = getline(line('.'))[ x - 1 : y - 1]
  elseif has_key(opts, 'is_visual.l')
    let x = getpos("'<")[2]
    let y = getpos("'>")[2]
    let keyword = getline(line('.'))[ x - 1 : y - 1]
    let search_meth = ".l"
  elseif has_key(opts, 'is_visual.r')
    let x = getpos("'<")[2]
    let y = getpos("'>")[2]
    let keyword = getline(line('.'))[ x - 1 : y - 1]
    let search_meth = ".r"
  elseif has_key(opts, 'is_arg')
    let keyword = opts['is_arg']
    let has_kw = 1
  else
    let l:oldiskeyword = &iskeyword
    if (g:rtagsUseColonKeyword == 1)
        setlocal iskeyword+=:
    endif
    let keyword = expand('<cword>')
    let &iskeyword = l:oldiskeyword
  endif

  if len(keyword) == 0
    return
  endif

  if has_key(opts, 'search_meth')
    let search_meth = opts['search_meth']
  endif

  if has_kw != 1
    "let keyword = substitute(keyword, "\\$", "\\\\\\\\\\\\$", "g")
    let k2 = substitute(keyword, "\\$", "\\\\$", "g")
    if k2 != keyword
      let keyword = "\'" . k2 . "\'"
    endif
    "let keyword = shellescape(keyword)
  endif

  redraw!
  echo "AnyJump: parsing: " . keyword

  try

    let ib = internal_buffer#GetClass().New()

    let ib.keyword                  = keyword
    let ib.language                 = lang
    let ib.source_win_id            = winnr()
    let ib.grouping_enabled         = g:any_jump_grouping_enabled

    if type(lang) == v:t_string
      let ib.definitions_grep_results = search#SearchDefinitions(lang, keyword, search_meth)
      if len(ib.definitions_grep_results) == 1 && ib.definitions_grep_results[0].text == "Aborted-cmd"
          throw "Aborted-cmd"
      elseif len(ib.definitions_grep_results) == 1 && ib.definitions_grep_results[0].text == "empty$result"
          let ib.definitions_grep_results = []
      endif
    endif

    if g:any_jump_references_enabled || len(ib.definitions_grep_results) == 0
      let ib.usages_opened       = v:true
      let usages_grep_results    = search#SearchUsages(ib, search_meth)
      if len(usages_grep_results) == 1 && usages_grep_results[0].text == "Aborted-cmd"
          throw "Aborted-cmd"
      elseif len(usages_grep_results) == 1 && usages_grep_results[0].text == "empty$result"
          let usages_grep_results = []
      endif
      let ib.usages_grep_results = []

      " filter out results found in definitions
      for result in usages_grep_results
        if index(ib.definitions_grep_results, result) == -1
          " not effective? ( TODO: deletion is more memory effective)
          call add(ib.usages_grep_results, result)
        endif
      endfor
    endif

  catch /Aborted-cmd/

    redraw!
    echo "AnyJump: parsing cancelled"
    sleep 900m
    redraw!
    echo " "
    return

  endtry

  redraw!
  echo " "

  " assign any-jump internal buffer to current tab
  let t:any_jump = ib

  call s:CreateUi(ib)
endfu

fu! s:JumpBack() abort
  redraw!
  echo " "

  " if called from an any-jump window then ignore ...
  let bname = bufname('%')
  if bname =~ 'any-jump lookup '
    return
  endif

  if exists('t:any_jump') && t:any_jump.previous_bufnr
    let new_previous = bufnr()
    execute(':buf ' . t:any_jump.previous_bufnr)
    let t:any_jump.previous_bufnr = new_previous
  endif
endfu

fu! s:JumpLastResults() abort
  redraw!
  echo " "

  " if called from an any-jump window then ignore ...
  let bname = bufname('%')
  if bname =~ 'any-jump lookup '
    return
  endif

  if exists('t:any_jump') " TODO: check for buffer visibility here
    let t:any_jump.source_win_id = winnr()
    call s:CreateUi(t:any_jump)
  endif
endfu

" ----------------------------------------------
" Event Handlers
" ----------------------------------------------

let s:available_open_actions = [ 'open', 'split', 'vsplit', 'tab' ]

fu! g:AnyJumpHandleOpen(...) abort
  redraw!
  echo " "
  let ui          = s:GetCurrentInternalBuffer()
  let action_item = ui.GetItemByPos()
  let open_action = 'open'

  if a:0
    let open_action = a:1
  endif

  if index(s:available_open_actions, open_action) == -1
    throw "invalid open action " . string(open_action)
  endif

  if type(action_item) != v:t_dict
    return 0
  endif

  " extract link from preview data
  if action_item.type == 'preview_text' && type(action_item.data.link) == v:t_dict
    let action_item = action_item.data.link
  endif

  if action_item.type == 'link'
    if type(ui.source_win_id) == v:t_number
      let win_id = ui.source_win_id

      if s:nvim
        close!
      else
        call popup_close(ui.popup_winid)
      endif

      " jump to desired window
      call win_gotoid(win_id)

      " save opened buffer for back-history
      let ui.previous_bufnr = bufnr()

      if open_action == 'open'
      elseif open_action == 'split'
        execute 'split'
      elseif open_action == 'vsplit'
        execute 'vsplit'
      elseif open_action == 'tab'
        execute 'tabnew'
      endif

      " open new file
      execute 'edit ' . action_item.data.path . '|:' . action_item.data.line_number
    endif

    " add current location to jump list
    execute "silent normal! ^"
    call setpos("''", getpos("."))

  elseif action_item.type == 'more_button'
    call g:AnyJumpLoadNextBatchResults()
  endif
endfu

fu! g:AnyJumpHandleClose() abort
  let ui = s:GetCurrentInternalBuffer()
  let ui.current_page = 1

  if s:nvim
    close!
  else
    call popup_close(ui.popup_winid)
  endif
endfu

fu! g:AnyJumpToggleListStyle() abort
  let ui = s:GetCurrentInternalBuffer()
  let next_style = g:any_jump_results_ui_style == 'filename_first' ?
        \'filename_last' : 'filename_first'

  let g:any_jump_results_ui_style = next_style

  let cursor_item = ui.TryFindOriginalLinkFromPos()
  let last_ln_nr  = ui.BufferLnum()

  call ui.StartUiTransaction()
  call ui.ClearBuffer(ui.vim_bufnr)
  call ui.RenderUi()
  call ui.EndUiTransaction()

  call ui.TryRestoreCursorForItem(cursor_item, {"last_ln_nr": last_ln_nr})
endfu

fu! g:AnyJumpHandleReferences() abort
  let ui = s:GetCurrentInternalBuffer()

  " close current opened usages
  if ui.usages_opened
    let ui.usages_opened = v:false

    let idx            = 0
    let layer_start_ln = 0
    let usages_started = v:false

    call ui.StartUiTransaction()

    " TODO: move to separate method RemoveUsages()
    for line in ui.items
      if has_key(line[0], 'data') && type(line[0].data) == v:t_dict
            \ && has_key(line[0].data, 'layer')
            \ && line[0].data.layer == 'usages'

        let line[0].gc = v:true " mark for destroy

        if !layer_start_ln
          let layer_start_ln = idx + 1
          let usages_started = v:true
        endif

        " remove from ui
        call deletebufline(ui.vim_bufnr, layer_start_ln)

      " remove preview lines for usages
      elseif usages_started && line[0].type == 'preview_text'
        let line[0].gc = v:true
        call deletebufline(ui.vim_bufnr, layer_start_ln)
      else
        let layer_start_ln = 0
      endif

      let idx += 1
    endfor

    call ui.EndUiTransaction()
    call ui.RemoveGarbagedLines()

    if !has("nvim")
      " mck - dont jump here
      "call ui.JumpToFirstOfType('link', 'definitions')
    endif

    let ui.usages_opened = v:false

    return v:true
  endif

  let grep_results  = search#SearchUsages(ui, 'gr')
  let filtered      = []

  " filter out results found in definitions
  for result in grep_results
    if index(ui.definitions_grep_results, result) == -1
      " not effective? ( TODO: deletion is more memory effective)
      call add(filtered, result)
    endif
  endfor

  let ui.usages_opened       = v:true
  let ui.usages_grep_results = filtered

  let marker_item = ui.GetFirstItemOfType('help_link')

  let start_ln = ui.GetItemLineNumber(marker_item)

  call ui.StartUiTransaction()
  call ui.RenderUiUsagesList(ui.usages_grep_results, start_ln)
  call ui.EndUiTransaction()

  if !has("nvim")
    " mck - dont jump here
    "call ui.JumpToFirstOfType('link', 'usages')
  endif
endfu

fu! g:AnyJumpToFirstLink() abort
  let ui = s:GetCurrentInternalBuffer()

  call ui.JumpToFirstOfType('link')

  return v:true
endfu

fu! g:AnyJumpToggleGrouping() abort
  let ui = s:GetCurrentInternalBuffer()

  let cursor_item = ui.TryFindOriginalLinkFromPos()
  let last_ln_nr  = ui.BufferLnum()

  call ui.StartUiTransaction()
  call ui.ClearBuffer(ui.vim_bufnr)

  let ui.preview_opened   = v:false
  let ui.grouping_enabled = ui.grouping_enabled ? v:false : v:true

  call ui.RenderUi()
  call ui.EndUiTransaction()

  if s:nvim
    call ui.TryRestoreCursorForItem(cursor_item, {"last_ln_nr": last_ln_nr})
  else
    call ui.RestorePopupCursor()
  endif
endfu

fu! g:AnyJumpLoadNextBatchResults() abort
  let ui = s:GetCurrentInternalBuffer()

  if ui.overmaxed_results_hidden == v:false
    return
  endif

  let cursor_item = ui.TryFindOriginalLinkFromPos()
  let last_ln_nr  = ui.BufferLnum()

  call ui.StartUiTransaction()
  call ui.ClearBuffer(ui.vim_bufnr)

  let ui.preview_opened = v:false
  let ui.current_page   = ui.current_page ? ui.current_page + 1 : 2

  call ui.RenderUi()
  call ui.EndUiTransaction()

  if s:nvim
    call ui.TryRestoreCursorForItem(cursor_item, {"last_ln_nr": last_ln_nr})
  else
    call ui.RestorePopupCursor()
  endif
endfu

fu! g:AnyJumpToggleAllResults() abort
  let ui = s:GetCurrentInternalBuffer()

  let ui.overmaxed_results_hidden =
        \ ui.overmaxed_results_hidden ? v:false : v:true

  call ui.StartUiTransaction()

  let cursor_item = ui.TryFindOriginalLinkFromPos()
  let last_ln_nr  = ui.BufferLnum()

  call ui.ClearBuffer(ui.vim_bufnr)

  let ui.preview_opened = v:false

  call ui.RenderUi()
  call ui.EndUiTransaction()

  if s:nvim
    call ui.TryRestoreCursorForItem(cursor_item, {"last_ln_nr": last_ln_nr})
  else
    call ui.RestorePopupCursor()
  endif
endfu

let g:oline = 0
let g:delta = 0

fu! g:AnyJumpHandlePreview() abort
  let ui          = s:GetCurrentInternalBuffer()
  let action_item = ui.TryFindOriginalLinkFromPos()

  let preview_actioned_on_self_link = v:false

  " dispatch to other items handler
  if type(action_item) == v:t_dict && action_item.type == 'more_button'
    call g:AnyJumpLoadNextBatchResults()
    return
  endif

  " remove all previews
  if ui.preview_opened
    let ui.preview_opened = v:false

    let idx            = 0
    let layer_start_ln = 0

    call ui.StartUiTransaction()

    let cx = 0
    for line in ui.items
      if line[0].type == 'preview_text'
        for item in line
          let item.gc = v:true " mark for destroy

          if has_key(item.data, 'link') && item.data.link == action_item
            let preview_actioned_on_self_link = v:true
          endif
        endfor

        let prev_line = ui.items[idx - 1]

        if !layer_start_ln
          let layer_start_ln = idx + 1
        endif

        " remove from ui
        call deletebufline(ui.vim_bufnr, layer_start_ln)
        let cx += 1

      elseif line[0].type == 'help_link'
        " not implemeted
      else
        let layer_start_ln = 0
      endif

      let idx += 1
    endfor

    call ui.RemoveGarbagedLines()
    call ui.EndUiTransaction()

    " hack to help correct line after preview close
    "echom "cx: " . cx
    if !has("nvim") && g:oline != 0
        let cline = line(".", ui.popup_winid)
        let g:delta = cline - g:oline
        "echom "d: " . g:delta . "cx: " . cx
        if g:delta > 0
            if g:delta > cx
                let g:delta = cx
            endif
            let adj = ""
            for i in range(1,g:delta)
                let adj .= "k\<C-y>"
            endfor
            "echo "adj: " . adj
            call feedkeys(adj, "n")
            redraw!
        endif

        if cline < g:oline
            let g:oline = cline
        else
            let d2 = cline - (g:oline + cx)
            if d2 <= 0
                return
            else
                let g:oline = line(".", ui.popup_winid)
            endif
        endif
    endif

  elseif !has("nvim")
      let g:oline = line(".", ui.popup_winid)
  endif

  if !has("nvim")
      let cline = line(".", ui.popup_winid)
      let bline = line("w$", ui.popup_winid)
      let d3 = bline - cline
      if d3 <= g:any_jump_preview_lines_count + 2
          let d4 = (g:any_jump_preview_lines_count + 3) - d3
          if g:delta > 0
              let d4 -= g:delta
          endif
          if d4 > 0
              let adj = "silent normal! " . d4 . "\<C-e>"
              call win_execute(ui.popup_winid, adj)
              redraw!
          endif
      endif
  endif

  " if clicked on just opened preview
  " then just close, not open again
  " if index(current_previewed_links, action_item) != -1
  if preview_actioned_on_self_link
    return
  endif

  if type(action_item) == v:t_dict
    if action_item.type == 'link' && !has_key(action_item.data, "group_header")
      call ui.StartUiTransaction()

      let ui.preview_opened = v:true

      let file_ln               = action_item.data.line_number
      let preview_before_offset = 2
      let preview_after_offset  = g:any_jump_preview_lines_count
      let preview_end_ln        = file_ln + preview_after_offset

      "let path = join([getcwd(), action_item.data.path], '/')
      let path = action_item.data.path

      if executable('bat')
          let p1 = file_ln - 2
          let p2 = file_ln + g:any_jump_preview_lines_count
          let cmd = 'bat -pp --color never -r ' . p1 . ':' . p2 . ' ' . path
          "echom "cmd: " . cmd
      else
          let cmd  = 'head -n ' . string(preview_end_ln) . ' "' . path
                \ . '" | tail -n ' . string(preview_after_offset + 1 + preview_before_offset)
      endif

      let preview = split(system(cmd), "\n")
      let render_ln = ui.GetItemLineNumber(action_item)

      for line in preview
        " TODO: move to method
        let filtered_line = substitute(line, '^\s*', '', 'g')
        let filtered_line = substitute(filtered_line, '\n', '', 'g')

        if filtered_line == action_item.text
          let items        = []
          let cur_text     = line
          let first_kw_pos = match(cur_text, '\<' . ui.keyword . '\>')

          while cur_text != ''
            if first_kw_pos == 0
              let cur_kw = ui.CreateItem("preview_text",
                    \ cur_text[first_kw_pos : first_kw_pos + len(ui.keyword) - 1],
                    \ g:AnyJumpGetColor("preview_keyword"),
                    \ { "link": action_item, "no_padding": v:true })

              call add(items, cur_kw)
              let cur_text = cur_text[first_kw_pos + len(ui.keyword) : -1]

            elseif first_kw_pos == -1
              let tail = cur_text
              let item = ui.CreateItem("preview_text", tail, g:AnyJumpGetColor('preview'), { "link": action_item, "no_padding": v:true })

              call add(items, item)
              let cur_text = ''

            else
              let head = cur_text[0 : first_kw_pos - 1]
              let head_item = ui.CreateItem("preview_text", head, g:AnyJumpGetColor('preview'), { "link": action_item, "no_padding": v:true })

              call add(items, head_item)

              let cur_kw = ui.CreateItem("preview_text",
                    \ cur_text[first_kw_pos : first_kw_pos + len(ui.keyword) -1 ],
                    \ g:AnyJumpGetColor("preview_keyword"),
                    \ { "link": action_item, "no_padding": v:true })

              call add(items, cur_kw)

              let cur_text = cur_text[first_kw_pos + len(ui.keyword) : -1]
            endif

            let first_kw_pos = match(cur_text, '\<' . ui.keyword . '\>')
          endwhile
        else
          let items = [ ui.CreateItem("preview_text", line, g:AnyJumpGetColor('preview'), { "link": action_item } ) ]
        endif

        call ui.AddLineAt(items, render_ln + 1)

        let render_ln += 1
      endfor

      call ui.EndUiTransaction()

    elseif action_item.type == 'help_link'
    endif
  endif

endfu

" ----------------------------------------------
" Script & Service functions
" ----------------------------------------------

if !exists('s:debug')
  let s:debug = v:false
endif

fu! s:ToggleDebug()
  let s:debug = s:debug ? v:false : v:true

  echo "debug enabled: " . s:debug
endfu

fu! s:log(message)
  echo "[any-jump] " . a:message
endfu

fu! s:log_debug(message)
  if s:debug == v:true
    echo "[any-jump] " . a:message
  endif
endfu

fu! s:RunSpecs() abort
  let errors = []
  let errors += search#RunSearchEnginesSpecs()
  let errors += search#RunRegexpSpecs()

  if len(errors) > 0
    for error in errors
      echoe error
    endfor
  endif

  call s:log("Tests finished")
endfu

" Commands
command! AnyJump call s:Jump()
command! AnyJumpDirLocal call s:Jump({"search_meth": ".l"})
command! AnyJumpDirRecur call s:Jump({"search_meth": ".r"})
command! -range AnyJumpVisual call s:Jump({"is_visual": v:true})
command! -range AnyJumpVisualDirLocal call s:Jump({"is_visual.l": v:true})
command! -range AnyJumpVisualDirRecur call s:Jump({"is_visual.r": v:true})
command! -nargs=1 AnyJumpArg call s:Jump({"is_arg": <f-args>})
command! AnyJumpBack call s:JumpBack()
command! AnyJumpLastResults call s:JumpLastResults()
command! AnyJumpRunSpecs call s:RunSpecs()

function! AnyJumpMethod(meth, keyword)
    if a:meth == 0
        call s:Jump({"is_arg": a:keyword})
    elseif a:meth == 1
        call s:Jump({"search_meth": ".l", "is_arg": a:keyword})
    elseif a:meth == 2
        call s:Jump({"search_meth": ".r", "is_arg": a:keyword})
    else
        redraw!
        echo "AnyJump: invalid search method (" . a:meth . ") {0,1,2}"
        sleep 1500m
        redraw!
        echo " "
    endif
endfunction

" Window KeyBindings
if s:nvim
  augroup anyjump
    au!
    au FileType any-jump nnoremap <buffer> <silent> o :call g:AnyJumpHandleOpen()<cr>
    au FileType any-jump nnoremap <buffer> <silent> <CR> :call g:AnyJumpHandleOpen()<cr>
    au FileType any-jump nnoremap <buffer> <silent> t :call g:AnyJumpHandleOpen('tab')<cr>
    au FileType any-jump nnoremap <buffer> <silent> <C-t> :call g:AnyJumpHandleOpen('tab')<cr>
    au FileType any-jump nnoremap <buffer> <silent> <C-t>t :call g:AnyJumpHandleOpen('tab')<cr>
    au FileType any-jump nnoremap <buffer> <silent> <C-t><C-t> :call g:AnyJumpHandleOpen('tab')<cr>
    au FileType any-jump nnoremap <buffer> <silent> s :call g:AnyJumpHandleOpen('split')<cr>
    au FileType any-jump nnoremap <buffer> <silent> <C-x> :call g:AnyJumpHandleOpen('split')<cr>
    au FileType any-jump nnoremap <buffer> <silent> v :call g:AnyJumpHandleOpen('vsplit')<cr>
    au FileType any-jump nnoremap <buffer> <silent> <C-v> :call g:AnyJumpHandleOpen('vsplit')<cr>

    au FileType any-jump nnoremap <buffer> <silent> p :call g:AnyJumpHandlePreview()<cr>
    au FileType any-jump nnoremap <buffer> <silent> <tab> :call g:AnyJumpHandlePreview()<cr>
    au FileType any-jump nnoremap <buffer> <silent> q :call g:AnyJumpHandleClose()<cr>
    au FileType any-jump nnoremap <buffer> <silent> x :call g:AnyJumpHandleClose()<cr>
    au FileType any-jump nnoremap <buffer> <silent> <C-q> :call g:AnyJumpHandleClose()<cr>
    au FileType any-jump nnoremap <buffer> <silent> <C-c> :call g:AnyJumpHandleClose()<cr>
    au FileType any-jump nnoremap <buffer> <silent> <M-q> :call g:AnyJumpHandleClose()<cr>
    " TODO: skip <Esc> ?
    au FileType any-jump nnoremap <buffer> <silent> r :call g:AnyJumpHandleReferences()<cr>
    au FileType any-jump nnoremap <buffer> <silent> b :call g:AnyJumpToFirstLink()<cr>
    au FileType any-jump nnoremap <buffer> <silent> 0 :call g:AnyJumpToFirstLink()<cr>
    au FileType any-jump nnoremap <buffer> <silent> <s-home> :call g:AnyJumpToFirstLink()<cr>
    au FileType any-jump nnoremap <buffer> <silent> <s-end> G
    au FileType any-jump nnoremap <buffer> <silent> T :call g:AnyJumpToggleGrouping()<cr>
    au FileType any-jump nnoremap <buffer> <silent> A :call g:AnyJumpToggleAllResults()<cr>
    au FileType any-jump nnoremap <buffer> <silent> a :call g:AnyJumpLoadNextBatchResults()<cr>
    au FileType any-jump nnoremap <buffer> <silent> L :call g:AnyJumpToggleListStyle()<cr>

    au FileType any-jump nmap <buffer> <silent> <Up>   k
    au FileType any-jump nmap <buffer> <silent> <Down> j
  augroup END
end

if g:any_jump_disable_default_keybindings == v:false
  nnoremap <leader>j  :AnyJump<CR>
  xnoremap <leader>j  :AnyJumpVisual<CR>
  nnoremap <leader>ab :AnyJumpBack<CR>
  nnoremap <leader>al :AnyJumpLastResults<CR>
end
