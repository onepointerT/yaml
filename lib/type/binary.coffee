resolveYamlBinary = (data) ->
    if data == null
        return false
    code = undefined
    idx = undefined
    bitlen = 0
    max = data.length
    map = BASE64_MAP
    # Convert one by one.
    idx = 0
    while idx < max
        code = map.indexOf(data.charAt(idx))
        # Skip CR/LF
        if code > 64
            idx++
            continue
        # Fail on illegal characters
        if code < 0
            return false
        bitlen += 6
        idx++
    # If there are any bits left, source was corrupted
    bitlen % 8 == 0

constructYamlBinary = (data) ->
    idx = undefined
    tailbits = undefined
    input = data.replace(/[\r\n=]/g, '')
    max = input.length
    map = BASE64_MAP
    bits = 0
    result = []
    # Collect by 6*4 bits (3 bytes)
    idx = 0
    while idx < max
        if idx % 4 == 0 and idx
            result.push bits >> 16 & 0xFF
            result.push bits >> 8 & 0xFF
            result.push bits & 0xFF
        bits = bits << 6 | map.indexOf(input.charAt(idx))
        idx++
    # Dump tail
    tailbits = max % 4 * 6
    if tailbits == 0
        result.push bits >> 16 & 0xFF
        result.push bits >> 8 & 0xFF
        result.push bits & 0xFF
    else if tailbits == 18
        result.push bits >> 10 & 0xFF
        result.push bits >> 2 & 0xFF
    else if tailbits == 12
        result.push bits >> 4 & 0xFF
    new Uint8Array(result)

representYamlBinary = (object) ->
    result = ''
    bits = 0
    idx = undefined
    tail = undefined
    max = object.length
    map = BASE64_MAP
    # Convert every three bytes to 4 ASCII characters.
    idx = 0
    while idx < max
        if idx % 3 == 0 and idx
            result += map[bits >> 18 & 0x3F]
            result += map[bits >> 12 & 0x3F]
            result += map[bits >> 6 & 0x3F]
            result += map[bits & 0x3F]
        bits = (bits << 8) + object[idx]
        idx++
    # Dump tail
    tail = max % 3
    if tail == 0
        result += map[bits >> 18 & 0x3F]
        result += map[bits >> 12 & 0x3F]
        result += map[bits >> 6 & 0x3F]
        result += map[bits & 0x3F]
    else if tail == 2
        result += map[bits >> 10 & 0x3F]
        result += map[bits >> 4 & 0x3F]
        result += map[bits << 2 & 0x3F]
        result += map[64]
    else if tail == 1
        result += map[bits >> 2 & 0x3F]
        result += map[bits << 4 & 0x3F]
        result += map[64]
        result += map[64]
    result

isBinary = (obj) ->
    Object::toString.call(obj) == '[object Uint8Array]'

'use strict'

###eslint-disable no-bitwise###

Type = require('../type')
# [ 64, 65, 66 ] -> [ padding, CR, LF ]
BASE64_MAP = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=\n\u000d'
module.exports = new Type('tag:yaml.org,2002:binary',
    kind: 'scalar'
    resolve: resolveYamlBinary
    construct: constructYamlBinary
    predicate: isBinary
    represent: representYamlBinary)
