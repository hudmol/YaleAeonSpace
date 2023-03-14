# Yale AeonSpace

(Copied from the required ArchivesSpace plugin, [yale_as_requests](https://github.com/hudmol/yale_as_requests))

## How it works

The `YaleAeonSpace` add-on provides a single input field which when actioned sends the query string to [yale_as_requests] via a new API endpoint `/plugins/yale_as_requests/search?q=YOUR_QUERY_STRING`. This endpoint returns a result set of container and BornDigital items which are mapped into Aeon Client table rows. This row data also contains a mapped Aeon request ready for the client to consume.

The search logic is as follows (`q` is the incoming query string):

+ Check if `q` is a call number i.e. does a resource identifier exactly match this value.
	+ Yes! We are now a Call Number search!
	+ No. Just a Normal search `:(`

## Call Number search

From `q` we now have a matching resource. A Call Number search will return any containers associated with this resource or its children and include any BornDigital items in the hierarchy.
Normal search

Find containers where:

+ `q` matches the barcode or
+ the top container display string contains `q` (where applicable the container display string includes the type, indicator, series label and barcode).

Find archival objects where:

+ `q` matches the title or
+ `q` matches the component id or
+ `q` matches the ref id or
+ `q` matches the URI

For any matching archival objects we return a row entry for each linked container. If the archival object is a born-digital item, then the archival object itself is mapped and returned as a result row.