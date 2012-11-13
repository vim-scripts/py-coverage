"
" Python filetype plugin for marking code coverage.
" Language:     Vim (ft=python)
" Maintainer:   Peter Sagerson <psagers at ignorare dot net>
" Version:      0.1.1
" URL:          https://bitbucket.org/psagers/vim-py-coverage
"

if exists("b:loaded_py_coverage_ftplugin")
    finish
endif
let b:loaded_py_coverage_ftplugin=1


let g:py_coverage_bin = ! exists('g:py_coverage_bin') ? 'coverage' : g:py_coverage_bin


highlight default link PyCoverageMissed Error


"
" Populate the quickfix list with the missed line numbers.
"
function! s:PyCoverageSetQuickfix()
    let newlist = []

    for line in PyCoverageMissedLines('')
        call add(newlist, {'bufnr': bufnr(''), 'lnum': line, 'text': 'Line not covered'})
    endfor

    call setqflist(newlist)
endfunction

command! PyCoverageSetQuickfix  :call s:PyCoverageSetQuickfix()


"
" Populate the current window's location list with the missed line numbers.
"
function! s:PyCoverageSetLoclist()
    let newlist = []

    for line in PyCoverageMissedLines('')
        call add(newlist, {'bufnr': bufnr(''), 'lnum': line, 'text': 'Line not covered'})
    endfor

    call setloclist(winnr(), newlist)
endfunction

command! PyCoverageSetLoclist  :call s:PyCoverageSetLoclist()


"
" Highlight the missed line numbers.
"
function! s:PyCoverageHighlight()
    call s:PyCoverageClear()

    for line in PyCoverageMissedLines('')
        call matchadd('PyCoverageMissed', '\%'.line.'l')
    endfor
endfunction

command! PyCoverageHighlight  :call s:PyCoverageHighlight()


"
" Clear highlighting.
"
function! s:PyCoverageClear()
    for m in getmatches()
        if m.group == 'PyCoverageMissed'
            call matchdelete(m.id)
        endif
    endfor
endfunction

command! PyCoverageClear  :call s:PyCoverageClear()


" Returns an array of line numbers representing all of the lines missed by the
" last coverage run in a given source file.
function! PyCoverageMissedLines(buffer)
    let linenos = []

    let sourcefile = fnamemodify(bufname(a:buffer), ':p')
    let report = s:CoverageReport(sourcefile)
    let lines = split(report, '[\r\n]\+')

    if len(lines) == 3
        let headers = lines[0]
        let fields = lines[2]
    else
        return []
    endif

    let offset = match(headers, 'Missing$')

    if offset >= 0
        let missing = fields[offset :]
    else
        return []
    endif

    for range in split(missing, ', ')
        let bounds = map(split(range, '-'), 'str2nr(v:val)')

        if len(bounds) == 1
            call extend(linenos, bounds)
        elseif len(bounds) == 2
            let lineno = bounds[0]
            while lineno <= bounds[1]
                call add(linenos, lineno)
                let lineno += 1
            endwhile
        endif
    endfor

    return linenos
endfunction


" Find the nearest .coverage file and generate a report for the given target
" source file. The report looks like:
"
" Name                 Stmts   Miss  Cover   Missing
" --------------------------------------------------
" python/module/path     169     30    82%   26-28, 64, 73-74, ...
function! s:CoverageReport(sourcefile)
    let coverage_dir = ''
    let report = ''

    if exists('g:py_coverage_dir')
        let coverage_dir = g:py_coverage_dir
    elseif filereadable(a:sourcefile)
        let suffixesadd_save = &suffixesadd
        let &suffixesadd = ''
        let coverage_db = findfile('.coverage', fnamemodify(a:sourcefile, ':h') . ';')
        let &suffixesadd = suffixesadd_save

        if coverage_db != ''
            let coverage_dir = fnamemodify(coverage_db, ':h')
        endif
    endif

    if coverage_dir != ''
        exec printf('cd! %s', fnameescape(coverage_dir))

        let report = system(printf('%s report -m --include=%s', shellescape(g:py_coverage_bin), shellescape(a:sourcefile)))

        if v:shell_error != 0
            echo report
            let report = ''
        endif

        cd! -
    endif

    return report
endfunction
