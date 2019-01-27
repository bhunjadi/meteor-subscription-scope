Connection = Meteor.connection.constructor

originalSubscribe = Connection::subscribe
Connection::subscribe = (args...) ->
  handle = originalSubscribe.apply @, args

  handle.scopeQuery = ->
    query = {}
    query["_sub_#{handle.subscriptionId}"] =
      $exists: true
    query

  handle

# Recreate the convenience method.
Meteor.subscribe = _.bind Meteor.connection.subscribe, Meteor.connection

###
  Problem with overriding _compileProjection is that it prevents _sub_ field being cleared. This happens when there are
  multiple subscription to the same document _id, but with different fields so the whole document cannot be removed
  when only one subscription is removed.

  Suppose the following case:
  sub1 - subscribed to field1
  sub2 - subscribed to field2

  When both subscriptions are active, raw document looks like this:
  {
    _id: 'doc_id',
    field1: value1,
    field2: value2,
    _sub_sub1_id: 1,
    _sub_sub2_id: 1,
  }

  Let's say that sub2 has some selector and something changes that should terminate the sub2. Consequently, field2 and
  _sub_sub2_id should be cleared.

  The problem is that only field2 is cleared and query on sub2 still fetches it but this time with field2 undefined.

  Reason for this is here: https://github.com/meteor/meteor/blob/e0763170e98d05b48b00ec47d5a03c8f2a00c09e/packages/mongo/collection.js#L179,
  - update(msg) function uses findOne and fields are processed in _compileProjection. _sub_sub2_id is not returned in that case
  - on L206 and further, _sub_sub2_id is NOT cleared because  if (EJSON.equals(doc[key], value)) is true (L213)
###

#originalCompileProjection = LocalCollection._compileProjection
#LocalCollection._compileProjection = (fields) ->
#  fun = originalCompileProjection fields
#
#  (obj) ->
#    res = fun obj
#
#    for field of res when field.lastIndexOf('_sub_', 0) is 0
#      delete res[field]
#
#    res
