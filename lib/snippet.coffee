# get snippet for a single line, respecting maxLength

getLine = (buffer, lineStart, lineEnd, position, maxLineLength) ->
    head = ''
    tail = ''
    maxHalfLength = Math.floor(maxLineLength / 2) - 1
    if position - lineStart > maxHalfLength
        head = ' ... '
        lineStart = position - maxHalfLength + head.length
    if lineEnd - position > maxHalfLength
        tail = ' ...'
        lineEnd = position + maxHalfLength - (tail.length)
    {
        str: head + buffer.slice(lineStart, lineEnd).replace(/\t/g, '→') + tail
        pos: position - lineStart + head.length
    }

padStart = (string, max) ->
    common.repeat(' ', max - (string.length)) + string

makeSnippet = (mark, options) ->
    options = Object.create(options or null)
    if !mark.buffer
        return null
    if !options.maxLength
        options.maxLength = 79
    if typeof options.indent != 'number'
        options.indent = 1
    if typeof options.linesBefore != 'number'
        options.linesBefore = 3
    if typeof options.linesAfter != 'number'
        options.linesAfter = 2
    re = /\r?\n|\r|\0/g
    lineStarts = [ 0 ]
    lineEnds = []
    match = undefined
    foundLineNo = -1
    while match = re.exec(mark.buffer)
        lineEnds.push match.index
        lineStarts.push match.index + match[0].length
        if mark.position <= match.index and foundLineNo < 0
            foundLineNo = lineStarts.length - 2
    if foundLineNo < 0
        foundLineNo = lineStarts.length - 1
    result = ''
    i = undefined
    line = undefined
    lineNoLength = Math.min(mark.line + options.linesAfter, lineEnds.length).toString().length
    maxLineLength = options.maxLength - (options.indent + lineNoLength + 3)
    i = 1
    while i <= options.linesBefore
        if foundLineNo - i < 0
            break
        line = getLine(mark.buffer, lineStarts[foundLineNo - i], lineEnds[foundLineNo - i], mark.position - (lineStarts[foundLineNo] - (lineStarts[foundLineNo - i])), maxLineLength)
        result = common.repeat(' ', options.indent) + padStart((mark.line - i + 1).toString(), lineNoLength) + ' | ' + line.str + '\n' + result
        i++
    line = getLine(mark.buffer, lineStarts[foundLineNo], lineEnds[foundLineNo], mark.position, maxLineLength)
    result += common.repeat(' ', options.indent) + padStart((mark.line + 1).toString(), lineNoLength) + ' | ' + line.str + '\n'
    result += common.repeat('-', options.indent + lineNoLength + 3 + line.pos) + '^' + '\n'
    i = 1
    while i <= options.linesAfter
        if foundLineNo + i >= lineEnds.length
            break
        line = getLine(mark.buffer, lineStarts[foundLineNo + i], lineEnds[foundLineNo + i], mark.position - (lineStarts[foundLineNo] - (lineStarts[foundLineNo + i])), maxLineLength)
        result += common.repeat(' ', options.indent) + padStart((mark.line + i + 1).toString(), lineNoLength) + ' | ' + line.str + '\n'
        i++
    result.replace /\n$/, ''

'use strict'
common = require('./common')
module.exports = makeSnippet
