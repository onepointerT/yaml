
import { FAILSAFE_SCHEMA, JSON_SCHEMA, dump, load } from '../index'

require('../index')
module.exports = require('../index')

onwarning: (except) ->
    console.log("#{except.name} -- #{except.message}")

module.exports.loadJson =  (text) ->
    options = {
        schema: JSON_SCHEMA
        json: true
        onWarning: onwarning
    }
    return load text, options

module.exports.loadJsonFromFile = (path) ->
    fd = await open path, 'r'
    fc = fd.createReadStream()
    return loadJson fc


module.exports.loadYaml = (text) ->
    options = {
        schema: FAILSAFE_SCHEMA
        json: false
        onWarning: onwarning
    }
    return load text, options

module.exports.loadFromFile = (path) ->
    fd = await open path, 'r'
    fc = fd.createReadStream()
    return loadYaml fc


module.exports.toFile = (yaml_obj, path) ->
    options = {
        schema: FAILSAFE_SCHEMA
    }
    fd = await open path, 'w'
    fc = fd.createWriteStream dump yaml_obj, options
    