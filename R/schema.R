readSchema =
  #
  # Fix this to use the relevant parse of readWSDLDoc to do the imports/includes.
  #
function(filename, createConverters = FALSE, verbose = FALSE,
         namespaces = c(ws = "http://schemas.xmlsoap.org/wsdl/",
                       xs = "http://www.w3.org/2001/XMLSchema"),
         followImports = TRUE,
         followIncludes = followImports,
         asNode = is(filename, "XMLInternalNode") && (is(filename, "AsIs") || xmlName(filename) == "schema"),
         checkCircularTypes = TRUE, simplify = FALSE, inline = TRUE, ...)
{
  schemaCollector = new.env()
  schemaCollector$.targetNamespaces = character()
  
  doc = if(is.character(filename))
           parseSchemaDoc(filename, namespaces = namespaces, followImports, followIncludes, verbose = verbose, prevSchema = schemaCollector, inline = inline)
        else
           filename

  if(inline) 
     processSchemaDoc(doc, tns, createConverters, verbose, checkCircularTypes = checkCircularTypes, simplify = simplify, asNode = asNode, ...)
  else {
     docURLs = ls(schemaCollector)
     docs = lapply(docURLs, get, schemaCollector)
     tns = schemaCollector$.targetNamespaces[docURLs]
     ans = mapply(processSchemaDoc, docs, tns,
                   MoreArgs = list(createConverters = createConverters, verbose = verbose,
                                   checkCircularTypes = FALSE, simplify = simplify, ...))
     new("SchemaCollection", ans)
  }
}

processSchemaDoc =
function(doc, tns,  createConverters = FALSE, verbose = FALSE,
         checkCircularTypes = TRUE, simplify = FALSE,
         asNode = is(doc, "XMLInternalNode") && (is(doc, "AsIs") || xmlName(doc) == "schema"), ...)
{  
  if(asNode && is(doc, "XMLInternalNode"))
    node = doc
  else
    node = xmlRoot(doc)
  
    # If this is a WSDL, get the types node.
  if(xmlName(node) %in% c("description", "definitions")) { # should use an XPath query with the namespace
                                                           # "http://www.w3.org/ns/wsdl"
     tmp = getNodeSet(doc, "//ws:types", namespaces)
     if(length(tmp))
       node = tmp[[1]]
  }

  tns = xmlGetAttr(node, "targetNamespace", NA)
  ans = processSchemaTypes(node, doc, createConverters = createConverters, verbose = verbose,
                               targetNamespace = tns, checkCircularTypes = checkCircularTypes, ...)

  invisible(if(simplify && length(ans) == 1 && is(ans, "SchemaCollection"))
               ans[[1]]
            else
               ans)
}



downloadSchema =
  #
  # Retrieve a WSDL and schema and the schema it refers to
  # and make them local. This is  helpful for local processing.
  # One can use a catalog entry to then redirect the XML parser
  # to use this.
  #
  # returns a character vector giving the names of the files
  # along with the names on the vector identifying the URLs
  # o = downloadSchema("http://sdw-ws.ecb.europa.eu/services/SDMXQuery?wsdl", "SDMX", verbose = TRUE)
  #
function(url, dir = ".", recursive = TRUE, verbose = FALSE, ignore = character())
{
  if(url %in% ignore) {
    cat("skipping", url, "\n")
    return(character())
  }
  f = getURLContent(url)
  pu = parseURI(url)
  name = basename(pu$path)
  if(pu$query != "")
    name = sprintf("%s?%s", name, pu$query)

  out = sprintf("%s%s%s", dir, .Platform$file.sep, name)
  names(out) = url
  
  if(verbose)
    cat(out, "\n")
  cat(f, file = out)
  doc = xmlParse(f, asText = TRUE)
  imps = getNodeSet(doc, "//xsd:import", c(xsd="http://www.w3.org/2001/XMLSchema"))



  for(x in imps) {
    u = xmlGetAttr(x, "schemaLocation")
    out = c(out, downloadSchema(u, dir = dir, recursive = recursive, verbose = verbose,
                                    ignore = c(ignore, names(out))))
  }

  out
}
