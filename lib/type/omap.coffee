resolveYamlOmap = (data) ->
    if data == null
        return true
    objectKeys = []
    index = undefined
    length = undefined
    pair = undefined
    pairKey = undefined
    pairHasKey = undefined
    object = data
    index = 0
    length = object.length
    while index < length
        pair = object[index]
        pairHasKey = false
        if _toString.call(pair) != '[object Object]'
            return false
        for pairKey of pair
            `pairKey = pairKey`
            if _hasOwnProperty.call(pair, pairKey)
                if !pairHasKey
                    pairHasKey = true
                else
                    return false
        if !pairHasKey
            return false
        if objectKeys.indexOf(pairKey) == -1
            objectKeys.push pairKey
        else
            return false
        index += 1
    true

constructYamlOmap = (data) ->
    if data != null then data else []

'use strict'
Type = require('../type')
_hasOwnProperty = Object::hasOwnProperty
_toString = Object::toString
module.exports = new Type('tag:yaml.org,2002:omap',
    kind: 'sequence'
    resolve: resolveYamlOmap
    construct: constructYamlOmap)
