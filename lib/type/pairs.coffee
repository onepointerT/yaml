resolveYamlPairs = (data) ->
    if data == null
        return true
    index = undefined
    length = undefined
    pair = undefined
    keys = undefined
    result = undefined
    object = data
    result = new Array(object.length)
    index = 0
    length = object.length
    while index < length
        pair = object[index]
        if _toString.call(pair) != '[object Object]'
            return false
        keys = Object.keys(pair)
        if keys.length != 1
            return false
        result[index] = [
            keys[0]
            pair[keys[0]]
        ]
        index += 1
    true

constructYamlPairs = (data) ->
    if data == null
        return []
    index = undefined
    length = undefined
    pair = undefined
    keys = undefined
    result = undefined
    object = data
    result = new Array(object.length)
    index = 0
    length = object.length
    while index < length
        pair = object[index]
        keys = Object.keys(pair)
        result[index] = [
            keys[0]
            pair[keys[0]]
        ]
        index += 1
    result

'use strict'
Type = require('../type')
_toString = Object::toString
module.exports = new Type('tag:yaml.org,2002:pairs',
    kind: 'sequence'
    resolve: resolveYamlPairs
    construct: constructYamlPairs)
