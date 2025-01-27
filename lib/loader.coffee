_class = (obj) ->
    Object::toString.call obj

is_EOL = (c) ->
    c == 0x0A or c == 0x0D

is_WHITE_SPACE = (c) ->
    c == 0x09 or c == 0x20

is_WS_OR_EOL = (c) ->
    c == 0x09 or c == 0x20 or c == 0x0A or c == 0x0D

is_FLOW_INDICATOR = (c) ->
    c == 0x2C or c == 0x5B or c == 0x5D or c == 0x7B or c == 0x7D

fromHexCode = (c) ->
    lc = undefined
    if 0x30 <= c and c <= 0x39
        return c - 0x30

    ###eslint-disable no-bitwise###

    lc = c | 0x20
    if 0x61 <= lc and lc <= 0x66
        return lc - 0x61 + 10
    -1

escapedHexLen = (c) ->
    if c == 0x78
        return 2
    if c == 0x75
        return 4
    if c == 0x55
        return 8
    0

fromDecimalCode = (c) ->
    if 0x30 <= c and c <= 0x39
        return c - 0x30
    -1

simpleEscapeSequence = (c) ->

    ### eslint-disable indent ###

    if c == 0x30 then '\u0000' else if c == 0x61 then '\u0007' else if c == 0x62 then '\u0008' else if c == 0x74 then '\u0009' else if c == 0x09 then '\u0009' else if c == 0x6E then '\n' else if c == 0x76 then '\u000b' else if c == 0x66 then '\u000c' else if c == 0x72 then '\u000d' else if c == 0x65 then '' else if c == 0x20 then ' ' else if c == 0x22 then '"' else if c == 0x2F then '/' else if c == 0x5C then '\\' else if c == 0x4E then '' else if c == 0x5F then ' ' else if c == 0x4C then '\u2028' else if c == 0x50 then '\u2029' else ''

charFromCodepoint = (c) ->
    if c <= 0xFFFF
        return String.fromCharCode(c)
    # Encode UTF-16 surrogate pair
    # https://en.wikipedia.org/wiki/UTF-16#Code_points_U.2B010000_to_U.2B10FFFF
    String.fromCharCode (c - 0x010000 >> 10) + 0xD800, (c - 0x010000 & 0x03FF) + 0xDC00

State = (input, options) ->
    @input = input
    @filename = options['filename'] or null
    @schema = options['schema'] or DEFAULT_SCHEMA
    @onWarning = options['onWarning'] or null
    # (Hidden) Remove? makes the loader to expect YAML 1.1 documents
    # if such documents have no explicit %YAML directive
    @legacy = options['legacy'] or false
    @json = options['json'] or false
    @listener = options['listener'] or null
    @implicitTypes = @schema.compiledImplicit
    @typeMap = @schema.compiledTypeMap
    @length = input.length
    @position = 0
    @line = 0
    @lineStart = 0
    @lineIndent = 0
    # position of first leading tab in the current line,
    # used to make sure there are no tabs in the indentation
    @firstTabInLine = -1
    @documents = []

    ###
    this.version;
    this.checkLineBreaks;
    this.tagMap;
    this.anchorMap;
    this.tag;
    this.anchor;
    this.kind;
    this.result;
    ###

    return

generateError = (state, message) ->
    mark = 
        name: state.filename
        buffer: state.input.slice(0, -1)
        position: state.position
        line: state.line
        column: state.position - (state.lineStart)
    mark.snippet = makeSnippet(mark)
    new YAMLException(message, mark)

throwError = (state, message) ->
    throw generateError(state, message)
    return

throwWarning = (state, message) ->
    if state.onWarning
        state.onWarning.call null, generateError(state, message)
    return

captureSegment = (state, start, end, checkJson) ->
    _position = undefined
    _length = undefined
    _character = undefined
    _result = undefined
    if start < end
        _result = state.input.slice(start, end)
        if checkJson
            _position = 0
            _length = _result.length
            while _position < _length
                _character = _result.charCodeAt(_position)
                if !(_character == 0x09 or 0x20 <= _character and _character <= 0x10FFFF)
                    throwError state, 'expected valid JSON character'
                _position += 1
        else if PATTERN_NON_PRINTABLE.test(_result)
            throwError state, 'the stream contains non-printable characters'
        state.result += _result
    return

mergeMappings = (state, destination, source, overridableKeys) ->
    sourceKeys = undefined
    key = undefined
    index = undefined
    quantity = undefined
    if !common.isObject(source)
        throwError state, 'cannot merge mappings; the provided source object is unacceptable'
    sourceKeys = Object.keys(source)
    index = 0
    quantity = sourceKeys.length
    while index < quantity
        key = sourceKeys[index]
        if !_hasOwnProperty.call(destination, key)
            destination[key] = source[key]
            overridableKeys[key] = true
        index += 1
    return

storeMappingPair = (state, _result, overridableKeys, keyTag, keyNode, valueNode, startLine, startLineStart, startPos) ->
    index = undefined
    quantity = undefined
    # The output is a plain object here, so keys can only be strings.
    # We need to convert keyNode to a string, but doing so can hang the process
    # (deeply nested arrays that explode exponentially using aliases).
    if Array.isArray(keyNode)
        keyNode = Array::slice.call(keyNode)
        index = 0
        quantity = keyNode.length
        while index < quantity
            if Array.isArray(keyNode[index])
                throwError state, 'nested arrays are not supported inside keys'
            if typeof keyNode == 'object' and _class(keyNode[index]) == '[object Object]'
                keyNode[index] = '[object Object]'
            index += 1
    # Avoid code execution in load() via toString property
    # (still use its own toString for arrays, timestamps,
    # and whatever user schema extensions happen to have @@toStringTag)
    if typeof keyNode == 'object' and _class(keyNode) == '[object Object]'
        keyNode = '[object Object]'
    keyNode = String(keyNode)
    if _result == null
        _result = {}
    if keyTag == 'tag:yaml.org,2002:merge'
        if Array.isArray(valueNode)
            index = 0
            quantity = valueNode.length
            while index < quantity
                mergeMappings state, _result, valueNode[index], overridableKeys
                index += 1
        else
            mergeMappings state, _result, valueNode, overridableKeys
    else
        if !state.json and !_hasOwnProperty.call(overridableKeys, keyNode) and _hasOwnProperty.call(_result, keyNode)
            state.line = startLine or state.line
            state.lineStart = startLineStart or state.lineStart
            state.position = startPos or state.position
            throwError state, 'duplicated mapping key'
        # used for this specific key only because Object.defineProperty is slow
        if keyNode == '__proto__'
            Object.defineProperty _result, keyNode,
                configurable: true
                enumerable: true
                writable: true
                value: valueNode
        else
            _result[keyNode] = valueNode
        delete overridableKeys[keyNode]
    _result

readLineBreak = (state) ->
    ch = undefined
    ch = state.input.charCodeAt(state.position)
    if ch == 0x0A
        state.position++
    else if ch == 0x0D
        state.position++
        if state.input.charCodeAt(state.position) == 0x0A
            state.position++
    else
        throwError state, 'a line break is expected'
    state.line += 1
    state.lineStart = state.position
    state.firstTabInLine = -1
    return

skipSeparationSpace = (state, allowComments, checkIndent) ->
    lineBreaks = 0
    ch = state.input.charCodeAt(state.position)
    while ch != 0
        while is_WHITE_SPACE(ch)
            if ch == 0x09 and state.firstTabInLine == -1
                state.firstTabInLine = state.position
            ch = state.input.charCodeAt(++state.position)
        if allowComments and ch == 0x23
            loop
                ch = state.input.charCodeAt(++state.position)
                unless ch != 0x0A and ch != 0x0D and ch != 0
                    break
        if is_EOL(ch)
            readLineBreak state
            ch = state.input.charCodeAt(state.position)
            lineBreaks++
            state.lineIndent = 0
            while ch == 0x20
                state.lineIndent++
                ch = state.input.charCodeAt(++state.position)
        else
            break
    if checkIndent != -1 and lineBreaks != 0 and state.lineIndent < checkIndent
        throwWarning state, 'deficient indentation'
    lineBreaks

testDocumentSeparator = (state) ->
    _position = state.position
    ch = undefined
    ch = state.input.charCodeAt(_position)
    # Condition state.position === state.lineStart is tested
    # in parent on each call, for efficiency. No needs to test here again.
    if (ch == 0x2D or ch == 0x2E) and ch == state.input.charCodeAt(_position + 1) and ch == state.input.charCodeAt(_position + 2)
        _position += 3
        ch = state.input.charCodeAt(_position)
        if ch == 0 or is_WS_OR_EOL(ch)
            return true
    false

writeFoldedLines = (state, count) ->
    if count == 1
        state.result += ' '
    else if count > 1
        state.result += common.repeat('\n', count - 1)
    return

readPlainScalar = (state, nodeIndent, withinFlowCollection) ->
    preceding = undefined
    following = undefined
    captureStart = undefined
    captureEnd = undefined
    hasPendingContent = undefined
    _line = undefined
    _lineStart = undefined
    _lineIndent = undefined
    _kind = state.kind
    _result = state.result
    ch = undefined
    ch = state.input.charCodeAt(state.position)
    if is_WS_OR_EOL(ch) or is_FLOW_INDICATOR(ch) or ch == 0x23 or ch == 0x26 or ch == 0x2A or ch == 0x21 or ch == 0x7C or ch == 0x3E or ch == 0x27 or ch == 0x22 or ch == 0x25 or ch == 0x40 or ch == 0x60
        return false
    if ch == 0x3F or ch == 0x2D
        following = state.input.charCodeAt(state.position + 1)
        if is_WS_OR_EOL(following) or withinFlowCollection and is_FLOW_INDICATOR(following)
            return false
    state.kind = 'scalar'
    state.result = ''
    captureStart = captureEnd = state.position
    hasPendingContent = false
    while ch != 0
        if ch == 0x3A
            following = state.input.charCodeAt(state.position + 1)
            if is_WS_OR_EOL(following) or withinFlowCollection and is_FLOW_INDICATOR(following)
                break
        else if ch == 0x23
            preceding = state.input.charCodeAt(state.position - 1)
            if is_WS_OR_EOL(preceding)
                break
        else if state.position == state.lineStart and testDocumentSeparator(state) or withinFlowCollection and is_FLOW_INDICATOR(ch)
            break
        else if is_EOL(ch)
            _line = state.line
            _lineStart = state.lineStart
            _lineIndent = state.lineIndent
            skipSeparationSpace state, false, -1
            if state.lineIndent >= nodeIndent
                hasPendingContent = true
                ch = state.input.charCodeAt(state.position)
                index += 1
                continue
            else
                state.position = captureEnd
                state.line = _line
                state.lineStart = _lineStart
                state.lineIndent = _lineIndent
                break
        if hasPendingContent
            captureSegment state, captureStart, captureEnd, false
            writeFoldedLines state, state.line - _line
            captureStart = captureEnd = state.position
            hasPendingContent = false
        if !is_WHITE_SPACE(ch)
            captureEnd = state.position + 1
        ch = state.input.charCodeAt(++state.position)
    captureSegment state, captureStart, captureEnd, false
    if state.result
        return true
    state.kind = _kind
    state.result = _result
    false

readSingleQuotedScalar = (state, nodeIndent) ->
    ch = undefined
    captureStart = undefined
    captureEnd = undefined
    ch = state.input.charCodeAt(state.position)
    if ch != 0x27
        return false
    state.kind = 'scalar'
    state.result = ''
    state.position++
    captureStart = captureEnd = state.position
    while (ch = state.input.charCodeAt(state.position)) != 0
        if ch == 0x27
            captureSegment state, captureStart, state.position, true
            ch = state.input.charCodeAt(++state.position)
            if ch == 0x27
                captureStart = state.position
                state.position++
                captureEnd = state.position
            else
                return true
        else if is_EOL(ch)
            captureSegment state, captureStart, captureEnd, true
            writeFoldedLines state, skipSeparationSpace(state, false, nodeIndent)
            captureStart = captureEnd = state.position
        else if state.position == state.lineStart and testDocumentSeparator(state)
            throwError state, 'unexpected end of the document within a single quoted scalar'
        else
            state.position++
            captureEnd = state.position
    throwError state, 'unexpected end of the stream within a single quoted scalar'
    return

readDoubleQuotedScalar = (state, nodeIndent) ->
    captureStart = undefined
    captureEnd = undefined
    hexLength = undefined
    hexResult = undefined
    tmp = undefined
    ch = undefined
    ch = state.input.charCodeAt(state.position)
    if ch != 0x22
        return false
    state.kind = 'scalar'
    state.result = ''
    state.position++
    captureStart = captureEnd = state.position
    while (ch = state.input.charCodeAt(state.position)) != 0
        if ch == 0x22
            captureSegment state, captureStart, state.position, true
            state.position++
            return true
        else if ch == 0x5C
            captureSegment state, captureStart, state.position, true
            ch = state.input.charCodeAt(++state.position)
            if is_EOL(ch)
                skipSeparationSpace state, false, nodeIndent
                # TODO: rework to inline fn with no type cast?
            else if ch < 256 and simpleEscapeCheck[ch]
                state.result += simpleEscapeMap[ch]
                state.position++
            else if (tmp = escapedHexLen(ch)) > 0
                hexLength = tmp
                hexResult = 0
                while hexLength > 0
                    ch = state.input.charCodeAt(++state.position)
                    if (tmp = fromHexCode(ch)) >= 0
                        hexResult = (hexResult << 4) + tmp
                    else
                        throwError state, 'expected hexadecimal character'
                    hexLength--
                state.result += charFromCodepoint(hexResult)
                state.position++
            else
                throwError state, 'unknown escape sequence'
            captureStart = captureEnd = state.position
        else if is_EOL(ch)
            captureSegment state, captureStart, captureEnd, true
            writeFoldedLines state, skipSeparationSpace(state, false, nodeIndent)
            captureStart = captureEnd = state.position
        else if state.position == state.lineStart and testDocumentSeparator(state)
            throwError state, 'unexpected end of the document within a double quoted scalar'
        else
            state.position++
            captureEnd = state.position
    throwError state, 'unexpected end of the stream within a double quoted scalar'
    return

readFlowCollection = (state, nodeIndent) ->
    readNext = true
    _line = undefined
    _lineStart = undefined
    _pos = undefined
    _tag = state.tag
    _result = undefined
    _anchor = state.anchor
    following = undefined
    terminator = undefined
    isPair = undefined
    isExplicitPair = undefined
    isMapping = undefined
    overridableKeys = Object.create(null)
    keyNode = undefined
    keyTag = undefined
    valueNode = undefined
    ch = undefined
    ch = state.input.charCodeAt(state.position)
    if ch == 0x5B
        terminator = 0x5D

        ### ] ###

        isMapping = false
        _result = []
    else if ch == 0x7B
        terminator = 0x7D

        ### } ###

        isMapping = true
        _result = {}
    else
        return false
    if state.anchor != null
        state.anchorMap[state.anchor] = _result
    ch = state.input.charCodeAt(++state.position)
    while ch != 0
        skipSeparationSpace state, true, nodeIndent
        ch = state.input.charCodeAt(state.position)
        if ch == terminator
            state.position++
            state.tag = _tag
            state.anchor = _anchor
            state.kind = if isMapping then 'mapping' else 'sequence'
            state.result = _result
            return true
        else if !readNext
            throwError state, 'missed comma between flow collection entries'
        else if ch == 0x2C
            # "flow collection entries can never be completely empty", as per YAML 1.2, section 7.4
            throwError state, 'expected the node content, but found \',\''
        keyTag = keyNode = valueNode = null
        isPair = isExplicitPair = false
        if ch == 0x3F
            following = state.input.charCodeAt(state.position + 1)
            if is_WS_OR_EOL(following)
                isPair = isExplicitPair = true
                state.position++
                skipSeparationSpace state, true, nodeIndent
        _line = state.line
        # Save the current line.
        _lineStart = state.lineStart
        _pos = state.position
        composeNode state, nodeIndent, CONTEXT_FLOW_IN, false, true
        keyTag = state.tag
        keyNode = state.result
        skipSeparationSpace state, true, nodeIndent
        ch = state.input.charCodeAt(state.position)
        if (isExplicitPair or state.line == _line) and ch == 0x3A
            isPair = true
            ch = state.input.charCodeAt(++state.position)
            skipSeparationSpace state, true, nodeIndent
            composeNode state, nodeIndent, CONTEXT_FLOW_IN, false, true
            valueNode = state.result
        if isMapping
            storeMappingPair state, _result, overridableKeys, keyTag, keyNode, valueNode, _line, _lineStart, _pos
        else if isPair
            _result.push storeMappingPair(state, null, overridableKeys, keyTag, keyNode, valueNode, _line, _lineStart, _pos)
        else
            _result.push keyNode
        skipSeparationSpace state, true, nodeIndent
        ch = state.input.charCodeAt(state.position)
        if ch == 0x2C
            readNext = true
            ch = state.input.charCodeAt(++state.position)
        else
            readNext = false
    throwError state, 'unexpected end of the stream within a flow collection'
    return

readBlockScalar = (state, nodeIndent) ->
    captureStart = undefined
    folding = undefined
    chomping = CHOMPING_CLIP
    didReadContent = false
    detectedIndent = false
    textIndent = nodeIndent
    emptyLines = 0
    atMoreIndented = false
    tmp = undefined
    ch = undefined
    ch = state.input.charCodeAt(state.position)
    if ch == 0x7C
        folding = false
    else if ch == 0x3E
        folding = true
    else
        return false
    state.kind = 'scalar'
    state.result = ''
    while ch != 0
        ch = state.input.charCodeAt(++state.position)
        if ch == 0x2B or ch == 0x2D
            if CHOMPING_CLIP == chomping
                chomping = if ch == 0x2B then CHOMPING_KEEP else CHOMPING_STRIP
            else
                throwError state, 'repeat of a chomping mode identifier'
        else if (tmp = fromDecimalCode(ch)) >= 0
            if tmp == 0
                throwError state, 'bad explicit indentation width of a block scalar; it cannot be less than one'
            else if !detectedIndent
                textIndent = nodeIndent + tmp - 1
                detectedIndent = true
            else
                throwError state, 'repeat of an indentation width identifier'
        else
            break
    if is_WHITE_SPACE(ch)
        loop
            ch = state.input.charCodeAt(++state.position)
            unless is_WHITE_SPACE(ch)
                break
        if ch == 0x23
            loop
                ch = state.input.charCodeAt(++state.position)
                unless !is_EOL(ch) and ch != 0
                    break
    while ch != 0
        readLineBreak state
        state.lineIndent = 0
        ch = state.input.charCodeAt(state.position)
        while (!detectedIndent or state.lineIndent < textIndent) and ch == 0x20
            state.lineIndent++
            ch = state.input.charCodeAt(++state.position)
        if !detectedIndent and state.lineIndent > textIndent
            textIndent = state.lineIndent
        if is_EOL(ch)
            emptyLines++
            hexLength--
            continue
        # End of the scalar.
        if state.lineIndent < textIndent
            # Perform the chomping.
            if chomping == CHOMPING_KEEP
                state.result += common.repeat('\n', if didReadContent then 1 + emptyLines else emptyLines)
            else if chomping == CHOMPING_CLIP
                if didReadContent
                    # i.e. only if the scalar is not empty.
                    state.result += '\n'
            # Break this `while` cycle and go to the funciton's epilogue.
            break
        # Folded style: use fancy rules to handle line breaks.
        if folding
            # Lines starting with white space characters (more-indented lines) are not folded.
            if is_WHITE_SPACE(ch)
                atMoreIndented = true
                # except for the first content line (cf. Example 8.1)
                state.result += common.repeat('\n', if didReadContent then 1 + emptyLines else emptyLines)
                # End of more-indented block.
            else if atMoreIndented
                atMoreIndented = false
                state.result += common.repeat('\n', emptyLines + 1)
                # Just one line break - perceive as the same line.
            else if emptyLines == 0
                if didReadContent
                    # i.e. only if we have already read some scalar content.
                    state.result += ' '
                # Several line breaks - perceive as different lines.
            else
                state.result += common.repeat('\n', emptyLines)
            # Literal style: just add exact number of line breaks between content lines.
        else
            # Keep all line breaks except the header line break.
            state.result += common.repeat('\n', if didReadContent then 1 + emptyLines else emptyLines)
        didReadContent = true
        detectedIndent = true
        emptyLines = 0
        captureStart = state.position
        while !is_EOL(ch) and ch != 0
            ch = state.input.charCodeAt(++state.position)
        captureSegment state, captureStart, state.position, false
    true

readBlockSequence = (state, nodeIndent) ->
    _line = undefined
    _tag = state.tag
    _anchor = state.anchor
    _result = []
    following = undefined
    detected = false
    ch = undefined
    # there is a leading tab before this token, so it can't be a block sequence/mapping;
    # it can still be flow sequence/mapping or a scalar
    if state.firstTabInLine != -1
        return false
    if state.anchor != null
        state.anchorMap[state.anchor] = _result
    ch = state.input.charCodeAt(state.position)
    while ch != 0
        if state.firstTabInLine != -1
            state.position = state.firstTabInLine
            throwError state, 'tab characters must not be used in indentation'
        if ch != 0x2D
            break
        following = state.input.charCodeAt(state.position + 1)
        if !is_WS_OR_EOL(following)
            break
        detected = true
        state.position++
        if skipSeparationSpace(state, true, -1)
            if state.lineIndent <= nodeIndent
                _result.push null
                ch = state.input.charCodeAt(state.position)
                hexLength--
                continue
        _line = state.line
        composeNode state, nodeIndent, CONTEXT_BLOCK_IN, false, true
        _result.push state.result
        skipSeparationSpace state, true, -1
        ch = state.input.charCodeAt(state.position)
        if (state.line == _line or state.lineIndent > nodeIndent) and ch != 0
            throwError state, 'bad indentation of a sequence entry'
        else if state.lineIndent < nodeIndent
            break
    if detected
        state.tag = _tag
        state.anchor = _anchor
        state.kind = 'sequence'
        state.result = _result
        return true
    false

readBlockMapping = (state, nodeIndent, flowIndent) ->
    following = undefined
    allowCompact = undefined
    _line = undefined
    _keyLine = undefined
    _keyLineStart = undefined
    _keyPos = undefined
    _tag = state.tag
    _anchor = state.anchor
    _result = {}
    overridableKeys = Object.create(null)
    keyTag = null
    keyNode = null
    valueNode = null
    atExplicitKey = false
    detected = false
    ch = undefined
    # there is a leading tab before this token, so it can't be a block sequence/mapping;
    # it can still be flow sequence/mapping or a scalar
    if state.firstTabInLine != -1
        return false
    if state.anchor != null
        state.anchorMap[state.anchor] = _result
    ch = state.input.charCodeAt(state.position)
    while ch != 0
        if !atExplicitKey and state.firstTabInLine != -1
            state.position = state.firstTabInLine
            throwError state, 'tab characters must not be used in indentation'
        following = state.input.charCodeAt(state.position + 1)
        _line = state.line
        # Save the current line.
        #
        # Explicit notation case. There are two separate blocks:
        # first for the key (denoted by "?") and second for the value (denoted by ":")
        #
        if (ch == 0x3F or ch == 0x3A) and is_WS_OR_EOL(following)
            if ch == 0x3F
                if atExplicitKey
                    storeMappingPair state, _result, overridableKeys, keyTag, keyNode, null, _keyLine, _keyLineStart, _keyPos
                    keyTag = keyNode = valueNode = null
                detected = true
                atExplicitKey = true
                allowCompact = true
            else if atExplicitKey
                # i.e. 0x3A/* : */ === character after the explicit key.
                atExplicitKey = false
                allowCompact = true
            else
                throwError state, 'incomplete explicit mapping pair; a key node is missed; or followed by a non-tabulated empty line'
            state.position += 1
            ch = following
            #
            # Implicit notation case. Flow-style node as the key first, then ":", and the value.
            #
        else
            _keyLine = state.line
            _keyLineStart = state.lineStart
            _keyPos = state.position
            if !composeNode(state, flowIndent, CONTEXT_FLOW_OUT, false, true)
                # Neither implicit nor explicit notation.
                # Reading is done. Go to the epilogue.
                break
            if state.line == _line
                ch = state.input.charCodeAt(state.position)
                while is_WHITE_SPACE(ch)
                    ch = state.input.charCodeAt(++state.position)
                if ch == 0x3A
                    ch = state.input.charCodeAt(++state.position)
                    if !is_WS_OR_EOL(ch)
                        throwError state, 'a whitespace character is expected after the key-value separator within a block mapping'
                    if atExplicitKey
                        storeMappingPair state, _result, overridableKeys, keyTag, keyNode, null, _keyLine, _keyLineStart, _keyPos
                        keyTag = keyNode = valueNode = null
                    detected = true
                    atExplicitKey = false
                    allowCompact = false
                    keyTag = state.tag
                    keyNode = state.result
                else if detected
                    throwError state, 'can not read an implicit mapping pair; a colon is missed'
                else
                    state.tag = _tag
                    state.anchor = _anchor
                    return true
                    # Keep the result of `composeNode`.
            else if detected
                throwError state, 'can not read a block mapping entry; a multiline key may not be an implicit key'
            else
                state.tag = _tag
                state.anchor = _anchor
                return true
                # Keep the result of `composeNode`.
        #
        # Common reading code for both explicit and implicit notations.
        #
        if state.line == _line or state.lineIndent > nodeIndent
            if atExplicitKey
                _keyLine = state.line
                _keyLineStart = state.lineStart
                _keyPos = state.position
            if composeNode(state, nodeIndent, CONTEXT_BLOCK_OUT, true, allowCompact)
                if atExplicitKey
                    keyNode = state.result
                else
                    valueNode = state.result
            if !atExplicitKey
                storeMappingPair state, _result, overridableKeys, keyTag, keyNode, valueNode, _keyLine, _keyLineStart, _keyPos
                keyTag = keyNode = valueNode = null
            skipSeparationSpace state, true, -1
            ch = state.input.charCodeAt(state.position)
        if (state.line == _line or state.lineIndent > nodeIndent) and ch != 0
            throwError state, 'bad indentation of a mapping entry'
        else if state.lineIndent < nodeIndent
            break
    #
    # Epilogue.
    #
    # Special case: last mapping's node contains only the key in explicit notation.
    if atExplicitKey
        storeMappingPair state, _result, overridableKeys, keyTag, keyNode, null, _keyLine, _keyLineStart, _keyPos
    # Expose the resulting mapping.
    if detected
        state.tag = _tag
        state.anchor = _anchor
        state.kind = 'mapping'
        state.result = _result
    detected

readTagProperty = (state) ->
    _position = undefined
    isVerbatim = false
    isNamed = false
    tagHandle = undefined
    tagName = undefined
    ch = undefined
    ch = state.input.charCodeAt(state.position)
    if ch != 0x21
        return false
    if state.tag != null
        throwError state, 'duplication of a tag property'
    ch = state.input.charCodeAt(++state.position)
    if ch == 0x3C
        isVerbatim = true
        ch = state.input.charCodeAt(++state.position)
    else if ch == 0x21
        isNamed = true
        tagHandle = '!!'
        ch = state.input.charCodeAt(++state.position)
    else
        tagHandle = '!'
    _position = state.position
    if isVerbatim
        loop
            ch = state.input.charCodeAt(++state.position)
            unless ch != 0 and ch != 0x3E
                break
        if state.position < state.length
            tagName = state.input.slice(_position, state.position)
            ch = state.input.charCodeAt(++state.position)
        else
            throwError state, 'unexpected end of the stream within a verbatim tag'
    else
        while ch != 0 and !is_WS_OR_EOL(ch)
            if ch == 0x21
                if !isNamed
                    tagHandle = state.input.slice(_position - 1, state.position + 1)
                    if !PATTERN_TAG_HANDLE.test(tagHandle)
                        throwError state, 'named tag handle cannot contain such characters'
                    isNamed = true
                    _position = state.position + 1
                else
                    throwError state, 'tag suffix cannot contain exclamation marks'
            ch = state.input.charCodeAt(++state.position)
        tagName = state.input.slice(_position, state.position)
        if PATTERN_FLOW_INDICATORS.test(tagName)
            throwError state, 'tag suffix cannot contain flow indicator characters'
    if tagName and !PATTERN_TAG_URI.test(tagName)
        throwError state, 'tag name cannot contain such characters: ' + tagName
    try
        tagName = decodeURIComponent(tagName)
    catch err
        throwError state, 'tag name is malformed: ' + tagName
    if isVerbatim
        state.tag = tagName
    else if _hasOwnProperty.call(state.tagMap, tagHandle)
        state.tag = state.tagMap[tagHandle] + tagName
    else if tagHandle == '!'
        state.tag = '!' + tagName
    else if tagHandle == '!!'
        state.tag = 'tag:yaml.org,2002:' + tagName
    else
        throwError state, 'undeclared tag handle "' + tagHandle + '"'
    true

readAnchorProperty = (state) ->
    _position = undefined
    ch = undefined
    ch = state.input.charCodeAt(state.position)
    if ch != 0x26
        return false
    if state.anchor != null
        throwError state, 'duplication of an anchor property'
    ch = state.input.charCodeAt(++state.position)
    _position = state.position
    while ch != 0 and !is_WS_OR_EOL(ch) and !is_FLOW_INDICATOR(ch)
        ch = state.input.charCodeAt(++state.position)
    if state.position == _position
        throwError state, 'name of an anchor node must contain at least one character'
    state.anchor = state.input.slice(_position, state.position)
    true

readAlias = (state) ->
    _position = undefined
    alias = undefined
    ch = undefined
    ch = state.input.charCodeAt(state.position)
    if ch != 0x2A
        return false
    ch = state.input.charCodeAt(++state.position)
    _position = state.position
    while ch != 0 and !is_WS_OR_EOL(ch) and !is_FLOW_INDICATOR(ch)
        ch = state.input.charCodeAt(++state.position)
    if state.position == _position
        throwError state, 'name of an alias node must contain at least one character'
    alias = state.input.slice(_position, state.position)
    if !_hasOwnProperty.call(state.anchorMap, alias)
        throwError state, 'unidentified alias "' + alias + '"'
    state.result = state.anchorMap[alias]
    skipSeparationSpace state, true, -1
    true

composeNode = (state, parentIndent, nodeContext, allowToSeek, allowCompact) ->
    allowBlockStyles = undefined
    allowBlockScalars = undefined
    allowBlockCollections = undefined
    indentStatus = 1
    atNewLine = false
    hasContent = false
    typeIndex = undefined
    typeQuantity = undefined
    typeList = undefined
    type = undefined
    flowIndent = undefined
    blockIndent = undefined
    if state.listener != null
        state.listener 'open', state
    state.tag = null
    state.anchor = null
    state.kind = null
    state.result = null
    allowBlockStyles = allowBlockScalars = allowBlockCollections = CONTEXT_BLOCK_OUT == nodeContext or CONTEXT_BLOCK_IN == nodeContext
    if allowToSeek
        if skipSeparationSpace(state, true, -1)
            atNewLine = true
            if state.lineIndent > parentIndent
                indentStatus = 1
            else if state.lineIndent == parentIndent
                indentStatus = 0
            else if state.lineIndent < parentIndent
                indentStatus = -1
    if indentStatus == 1
        while readTagProperty(state) or readAnchorProperty(state)
            if skipSeparationSpace(state, true, -1)
                atNewLine = true
                allowBlockCollections = allowBlockStyles
                if state.lineIndent > parentIndent
                    indentStatus = 1
                else if state.lineIndent == parentIndent
                    indentStatus = 0
                else if state.lineIndent < parentIndent
                    indentStatus = -1
            else
                allowBlockCollections = false
    if allowBlockCollections
        allowBlockCollections = atNewLine or allowCompact
    if indentStatus == 1 or CONTEXT_BLOCK_OUT == nodeContext
        if CONTEXT_FLOW_IN == nodeContext or CONTEXT_FLOW_OUT == nodeContext
            flowIndent = parentIndent
        else
            flowIndent = parentIndent + 1
        blockIndent = state.position - (state.lineStart)
        if indentStatus == 1
            if allowBlockCollections and (readBlockSequence(state, blockIndent) or readBlockMapping(state, blockIndent, flowIndent)) or readFlowCollection(state, flowIndent)
                hasContent = true
            else
                if allowBlockScalars and readBlockScalar(state, flowIndent) or readSingleQuotedScalar(state, flowIndent) or readDoubleQuotedScalar(state, flowIndent)
                    hasContent = true
                else if readAlias(state)
                    hasContent = true
                    if state.tag != null or state.anchor != null
                        throwError state, 'alias node should not have any properties'
                else if readPlainScalar(state, flowIndent, CONTEXT_FLOW_IN == nodeContext)
                    hasContent = true
                    if state.tag == null
                        state.tag = '?'
                if state.anchor != null
                    state.anchorMap[state.anchor] = state.result
        else if indentStatus == 0
            # Special case: block sequences are allowed to have same indentation level as the parent.
            # http://www.yaml.org/spec/1.2/spec.html#id2799784
            hasContent = allowBlockCollections and readBlockSequence(state, blockIndent)
    if state.tag == null
        if state.anchor != null
            state.anchorMap[state.anchor] = state.result
    else if state.tag == '?'
        # Implicit resolving is not allowed for non-scalar types, and '?'
        # non-specific tag is only automatically assigned to plain scalars.
        #
        # We only need to check kind conformity in case user explicitly assigns '?'
        # tag, for example like this: "!<?> [0]"
        #
        if state.result != null and state.kind != 'scalar'
            throwError state, 'unacceptable node kind for !<?> tag; it should be "scalar", not "' + state.kind + '"'
        typeIndex = 0
        typeQuantity = state.implicitTypes.length
        while typeIndex < typeQuantity
            type = state.implicitTypes[typeIndex]
            if type.resolve(state.result)
                # `state.result` updated in resolver if matched
                state.result = type.construct(state.result)
                state.tag = type.tag
                if state.anchor != null
                    state.anchorMap[state.anchor] = state.result
                break
            typeIndex += 1
    else if state.tag != '!'
        if _hasOwnProperty.call(state.typeMap[state.kind or 'fallback'], state.tag)
            type = state.typeMap[state.kind or 'fallback'][state.tag]
        else
            # looking for multi type
            type = null
            typeList = state.typeMap.multi[state.kind or 'fallback']
            typeIndex = 0
            typeQuantity = typeList.length
            while typeIndex < typeQuantity
                if state.tag.slice(0, typeList[typeIndex].tag.length) == typeList[typeIndex].tag
                    type = typeList[typeIndex]
                    break
                typeIndex += 1
        if !type
            throwError state, 'unknown tag !<' + state.tag + '>'
        if state.result != null and type.kind != state.kind
            throwError state, 'unacceptable node kind for !<' + state.tag + '> tag; it should be "' + type.kind + '", not "' + state.kind + '"'
        if !type.resolve(state.result, state.tag)
            # `state.result` updated in resolver if matched
            throwError state, 'cannot resolve a node with !<' + state.tag + '> explicit tag'
        else
            state.result = type.construct(state.result, state.tag)
            if state.anchor != null
                state.anchorMap[state.anchor] = state.result
    if state.listener != null
        state.listener 'close', state
    state.tag != null or state.anchor != null or hasContent

readDocument = (state) ->
    documentStart = state.position
    _position = undefined
    directiveName = undefined
    directiveArgs = undefined
    hasDirectives = false
    ch = undefined
    state.version = null
    state.checkLineBreaks = state.legacy
    state.tagMap = Object.create(null)
    state.anchorMap = Object.create(null)
    while (ch = state.input.charCodeAt(state.position)) != 0
        skipSeparationSpace state, true, -1
        ch = state.input.charCodeAt(state.position)
        if state.lineIndent > 0 or ch != 0x25
            break
        hasDirectives = true
        ch = state.input.charCodeAt(++state.position)
        _position = state.position
        while ch != 0 and !is_WS_OR_EOL(ch)
            ch = state.input.charCodeAt(++state.position)
        directiveName = state.input.slice(_position, state.position)
        directiveArgs = []
        if directiveName.length < 1
            throwError state, 'directive name must not be less than one character in length'
        while ch != 0
            while is_WHITE_SPACE(ch)
                ch = state.input.charCodeAt(++state.position)
            if ch == 0x23
                loop
                    ch = state.input.charCodeAt(++state.position)
                    unless ch != 0 and !is_EOL(ch)
                        break
                break
            if is_EOL(ch)
                break
            _position = state.position
            while ch != 0 and !is_WS_OR_EOL(ch)
                ch = state.input.charCodeAt(++state.position)
            directiveArgs.push state.input.slice(_position, state.position)
        if ch != 0
            readLineBreak state
        if _hasOwnProperty.call(directiveHandlers, directiveName)
            directiveHandlers[directiveName] state, directiveName, directiveArgs
        else
            throwWarning state, 'unknown document directive "' + directiveName + '"'
    skipSeparationSpace state, true, -1
    if state.lineIndent == 0 and state.input.charCodeAt(state.position) == 0x2D and state.input.charCodeAt(state.position + 1) == 0x2D and state.input.charCodeAt(state.position + 2) == 0x2D
        state.position += 3
        skipSeparationSpace state, true, -1
    else if hasDirectives
        throwError state, 'directives end mark is expected'
    composeNode state, state.lineIndent - 1, CONTEXT_BLOCK_OUT, false, true
    skipSeparationSpace state, true, -1
    if state.checkLineBreaks and PATTERN_NON_ASCII_LINE_BREAKS.test(state.input.slice(documentStart, state.position))
        throwWarning state, 'non-ASCII line breaks are interpreted as content'
    state.documents.push state.result
    if state.position == state.lineStart and testDocumentSeparator(state)
        if state.input.charCodeAt(state.position) == 0x2E
            state.position += 3
            skipSeparationSpace state, true, -1
        return
    if state.position < state.length - 1
        throwError state, 'end of the stream or a document separator is expected'
    else
        return
    return

loadDocuments = (input, options) ->
    input = String(input)
    options = options or {}
    if input.length != 0
        # Add tailing `\n` if not exists
        if input.charCodeAt(input.length - 1) != 0x0A and input.charCodeAt(input.length - 1) != 0x0D
            input += '\n'
        # Strip BOM
        if input.charCodeAt(0) == 0xFEFF
            input = input.slice(1)
    state = new State(input, options)
    nullpos = input.indexOf('\u0000')
    if nullpos != -1
        state.position = nullpos
        throwError state, 'null byte is not allowed in input'
    # Use 0 as string terminator. That significantly simplifies bounds check.
    state.input += '\u0000'
    while state.input.charCodeAt(state.position) == 0x20
        state.lineIndent += 1
        state.position += 1
    while state.position < state.length - 1
        readDocument state
    state.documents

loadAll = (input, iterator, options) ->
    if iterator != null and typeof iterator == 'object' and typeof options == 'undefined'
        options = iterator
        iterator = null
    documents = loadDocuments(input, options)
    if typeof iterator != 'function'
        return documents
    index = 0
    length = documents.length
    while index < length
        iterator documents[index]
        index += 1
    return

load = (input, options) ->
    documents = loadDocuments(input, options)
    if documents.length == 0

        ###eslint-disable no-undefined###

        return undefined
    else if documents.length == 1
        return documents[0]
    throw new YAMLException('expected a single document in the stream, but found more')
    return

'use strict'

###eslint-disable max-len,no-use-before-define###

common = require('./common')
YAMLException = require('./exception')
makeSnippet = require('./snippet')
DEFAULT_SCHEMA = require('./schema/default')
_hasOwnProperty = Object::hasOwnProperty
CONTEXT_FLOW_IN = 1
CONTEXT_FLOW_OUT = 2
CONTEXT_BLOCK_IN = 3
CONTEXT_BLOCK_OUT = 4
CHOMPING_CLIP = 1
CHOMPING_STRIP = 2
CHOMPING_KEEP = 3
PATTERN_NON_PRINTABLE = /[\x00-\x08\x0B\x0C\x0E-\x1F\x7F-\x84\x86-\x9F\uFFFE\uFFFF]|[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?:[^\uD800-\uDBFF]|^)[\uDC00-\uDFFF]/
PATTERN_NON_ASCII_LINE_BREAKS = /[\x85\u2028\u2029]/
PATTERN_FLOW_INDICATORS = /[,\[\]\{\}]/
PATTERN_TAG_HANDLE = /^(?:!|!!|![a-z\-]+!)$/i
PATTERN_TAG_URI = /^(?:!|[^,\[\]\{\}])(?:%[0-9a-f]{2}|[0-9a-z\-#;\/\?:@&=\+\$,_\.!~\*'\(\)\[\]])*$/i
simpleEscapeCheck = new Array(256)
# integer, for fast access
simpleEscapeMap = new Array(256)
i = 0
while i < 256
    simpleEscapeCheck[i] = if simpleEscapeSequence(i) then 1 else 0
    simpleEscapeMap[i] = simpleEscapeSequence(i)
    i++
directiveHandlers = 
    YAML: (state, name, args) ->
        match = undefined
        major = undefined
        minor = undefined
        if state.version != null
            throwError state, 'duplication of %YAML directive'
        if args.length != 1
            throwError state, 'YAML directive accepts exactly one argument'
        match = /^([0-9]+)\.([0-9]+)$/.exec(args[0])
        if match == null
            throwError state, 'ill-formed argument of the YAML directive'
        major = parseInt(match[1], 10)
        minor = parseInt(match[2], 10)
        if major != 1
            throwError state, 'unacceptable YAML version of the document'
        state.version = args[0]
        state.checkLineBreaks = minor < 2
        if minor != 1 and minor != 2
            throwWarning state, 'unsupported YAML version of the document'
        return
    TAG: (state, name, args) ->
        handle = undefined
        prefix = undefined
        if args.length != 2
            throwError state, 'TAG directive accepts exactly two arguments'
        handle = args[0]
        prefix = args[1]
        if !PATTERN_TAG_HANDLE.test(handle)
            throwError state, 'ill-formed tag handle (first argument) of the TAG directive'
        if _hasOwnProperty.call(state.tagMap, handle)
            throwError state, 'there is a previously declared suffix for "' + handle + '" tag handle'
        if !PATTERN_TAG_URI.test(prefix)
            throwError state, 'ill-formed tag prefix (second argument) of the TAG directive'
        try
            prefix = decodeURIComponent(prefix)
        catch err
            throwError state, 'tag prefix is malformed: ' + prefix
        state.tagMap[handle] = prefix
        return
module.exports.loadAll = loadAll
module.exports.load = load
