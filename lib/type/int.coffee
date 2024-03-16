isHexCode = (c) ->
    0x30 <= c and c <= 0x39 or 0x41 <= c and c <= 0x46 or 0x61 <= c and c <= 0x66

isOctCode = (c) ->
    0x30 <= c and c <= 0x37

isDecCode = (c) ->
    0x30 <= c and c <= 0x39

resolveYamlInteger = (data) ->
    if data == null
        return false
    max = data.length
    index = 0
    hasDigits = false
    ch = undefined
    if !max
        return false
    ch = data[index]
    # sign
    if ch == '-' or ch == '+'
        ch = data[++index]
    if ch == '0'
        # 0
        if index + 1 == max
            return true
        ch = data[++index]
        # base 2, base 8, base 16
        if ch == 'b'
            # base 2
            index++
            while index < max
                ch = data[index]
                if ch == '_'
                    index++
                    continue
                if ch != '0' and ch != '1'
                    return false
                hasDigits = true
                index++
            return hasDigits and ch != '_'
        if ch == 'x'
            # base 16
            index++
            while index < max
                ch = data[index]
                if ch == '_'
                    index++
                    continue
                if !isHexCode(data.charCodeAt(index))
                    return false
                hasDigits = true
                index++
            return hasDigits and ch != '_'
        if ch == 'o'
            # base 8
            index++
            while index < max
                ch = data[index]
                if ch == '_'
                    index++
                    continue
                if !isOctCode(data.charCodeAt(index))
                    return false
                hasDigits = true
                index++
            return hasDigits and ch != '_'
    # base 10 (except 0)
    # value should not start with `_`;
    if ch == '_'
        return false
    while index < max
        ch = data[index]
        if ch == '_'
            index++
            continue
        if !isDecCode(data.charCodeAt(index))
            return false
        hasDigits = true
        index++
    # Should have digits and should not end with `_`
    if !hasDigits or ch == '_'
        return false
    true

constructYamlInteger = (data) ->
    value = data
    sign = 1
    ch = undefined
    if value.indexOf('_') != -1
        value = value.replace(/_/g, '')
    ch = value[0]
    if ch == '-' or ch == '+'
        if ch == '-'
            sign = -1
        value = value.slice(1)
        ch = value[0]
    if value == '0'
        return 0
    if ch == '0'
        if value[1] == 'b'
            return sign * parseInt(value.slice(2), 2)
        if value[1] == 'x'
            return sign * parseInt(value.slice(2), 16)
        if value[1] == 'o'
            return sign * parseInt(value.slice(2), 8)
    sign * parseInt(value, 10)

isInteger = (object) ->
    Object::toString.call(object) == '[object Number]' and object % 1 == 0 and !common.isNegativeZero(object)

'use strict'
common = require('../common')
Type = require('../type')
module.exports = new Type('tag:yaml.org,2002:int',
    kind: 'scalar'
    resolve: resolveYamlInteger
    construct: constructYamlInteger
    predicate: isInteger
    represent:
        binary: (obj) ->
            if obj >= 0 then '0b' + obj.toString(2) else '-0b' + obj.toString(2).slice(1)
        octal: (obj) ->
            if obj >= 0 then '0o' + obj.toString(8) else '-0o' + obj.toString(8).slice(1)
        decimal: (obj) ->
            obj.toString 10
        hexadecimal: (obj) ->
            if obj >= 0 then '0x' + obj.toString(16).toUpperCase() else '-0x' + obj.toString(16).toUpperCase().slice(1)
    defaultStyle: 'decimal'
    styleAliases:
        binary: [
            2
            'bin'
        ]
        octal: [
            8
            'oct'
        ]
        decimal: [
            10
            'dec'
        ]
        hexadecimal: [
            16
            'hex'
        ])
