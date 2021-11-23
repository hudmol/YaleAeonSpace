-- Serialization format is just keys and values packed together like KVKVKVKV
--
-- Each K or V can be a string, number or boolean.  They're serialized as follows:
--
--   String: 's' + <len: 16 ASCII base 10 digit length field> + <char data with `len` chars>
--   Number: 'n' + <len: 16 ASCII base 10 digit length field> + <char data with `len` chars generated with tonumber(n)>
--   Boolean: 'b1' for true; 'b0' for false
--
function serializeKvs(kvs)
   function serialize(thing)
      if type(thing) == "string" then
         return string.format("s%016d%s", string.len(thing), thing)
      elseif type(thing) == "number" then
         local s = tostring(thing)
         return string.format("n%016d%s", string.len(s), s)
      elseif type(thing) == "boolean" then
         if thing then
            return "b1"
         else
            return "b0"
         end
      else
         error("Can only serialize strings, booleans a numbers right now")
      end
   end

   out = ""
   for key in pairs(kvs) do
      out = out .. serialize(key)
      out = out .. serialize(kvs[key])
   end

   return out
end

function deserializeKvs(s)
   function deserialize(thing)
      local type = string.sub(thing, 1, 1)
      if type == "s" then
         local len = tonumber(string.sub(thing, 2, 17))
         return string.sub(thing, 18, 18 + len - 1), string.sub(thing, 18 + len)
      elseif type == "n" then
         local len = tonumber(string.sub(thing, 2, 17))
         return tonumber(string.sub(thing, 18, 18 + len - 1)), string.sub(thing, 18 + len)
      elseif type == "b" then
         local result = string.sub(thing, 2, 2) == "1"
         return result, string.sub(thing, 3)
      else
         error("Can only deserialize strings, booleans a numbers right now")
      end
   end

   local rest = s

   local result = {}

   while rest ~= "" do
      key, rest = deserialize(rest)
      value, rest = deserialize(rest)

      result[key] = value
   end

   return result
end
