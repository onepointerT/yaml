isNothing = (subject) ->
    typeof subject == 'undefined' or subject == null

isObject = (subject) ->
    typeof subject == 'object' and subject != null

toArray = (sequence) ->
    if Array.isArray(sequence)
        return sequence
    else if isNothing(sequence)
        return []
    [ sequence ]

extend = (target, source) ->
    index = undefined
    length = undefined
    key = undefined
    sourceKeys = undefined
    if source
        sourceKeys = Object.keys(source)
        index = 0
        length = sourceKeys.length
        while index < length
            key = sourceKeys[index]
            target[key] = source[key]
            index += 1
    target

repeat = (string, count) ->
    result = ''
    cycle = undefined
    cycle = 0
    while cycle < count
        result += string
        cycle += 1
    result

isNegativeZero = (number) ->
    number == 0 and Number.NEGATIVE_INFINITY == 1 / number

'use strict'
module.exports.isNothing = isNothing
module.exports.isObject = isObject
module.exports.toArray = toArray
module.exports.repeat = repeat
module.exports.isNegativeZero = isNegativeZero
module.exports.extend = extend
