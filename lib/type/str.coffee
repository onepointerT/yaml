'use strict'
Type = require('../type')
module.exports = new Type('tag:yaml.org,2002:str',
    kind: 'scalar'
    construct: (data) ->
        if data != null then data else ''
)
