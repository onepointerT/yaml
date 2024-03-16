# [11] tz_minute

resolveYamlTimestamp = (data) ->
    if data == null
        return false
    if YAML_DATE_REGEXP.exec(data) != null
        return true
    if YAML_TIMESTAMP_REGEXP.exec(data) != null
        return true
    false

constructYamlTimestamp = (data) ->
    match = undefined
    year = undefined
    month = undefined
    day = undefined
    hour = undefined
    minute = undefined
    second = undefined
    fraction = 0
    delta = null
    tz_hour = undefined
    tz_minute = undefined
    date = undefined
    match = YAML_DATE_REGEXP.exec(data)
    if match == null
        match = YAML_TIMESTAMP_REGEXP.exec(data)
    if match == null
        throw new Error('Date resolve error')
    # match: [1] year [2] month [3] day
    year = +match[1]
    month = +match[2] - 1
    # JS month starts with 0
    day = +match[3]
    if !match[4]
        # no hour
        return new Date(Date.UTC(year, month, day))
    # match: [4] hour [5] minute [6] second [7] fraction
    hour = +match[4]
    minute = +match[5]
    second = +match[6]
    if match[7]
        fraction = match[7].slice(0, 3)
        while fraction.length < 3
            # milli-seconds
            fraction += '0'
        fraction = +fraction
    # match: [8] tz [9] tz_sign [10] tz_hour [11] tz_minute
    if match[9]
        tz_hour = +match[10]
        tz_minute = +(match[11] or 0)
        delta = (tz_hour * 60 + tz_minute) * 60000
        # delta in mili-seconds
        if match[9] == '-'
            delta = -delta
    date = new Date(Date.UTC(year, month, day, hour, minute, second, fraction))
    if delta
        date.setTime date.getTime() - delta
    date

representYamlTimestamp = (object) ->
    object.toISOString()

'use strict'
Type = require('../type')
YAML_DATE_REGEXP = new RegExp('^([0-9][0-9][0-9][0-9])' + '-([0-9][0-9])' + '-([0-9][0-9])$')
# [3] day
YAML_TIMESTAMP_REGEXP = new RegExp('^([0-9][0-9][0-9][0-9])' + '-([0-9][0-9]?)' + '-([0-9][0-9]?)' + '(?:[Tt]|[ \\t]+)' + '([0-9][0-9]?)' + ':([0-9][0-9])' + ':([0-9][0-9])' + '(?:\\.([0-9]*))?' + '(?:[ \\t]*(Z|([-+])([0-9][0-9]?)' + '(?::([0-9][0-9]))?))?$')
module.exports = new Type('tag:yaml.org,2002:timestamp',
    kind: 'scalar'
    resolve: resolveYamlTimestamp
    construct: constructYamlTimestamp
    instanceOf: Date
    represent: representYamlTimestamp)
