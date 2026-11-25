<?xml version="1.0" encoding="UTF-8"?>
<!--
This builder is released under a BSD-3 license as part of the CIMantic Graphs library developed by PNNL.

This software was created under a project sponsored by the U.S. Department of Energy's Office of Electricity,
an agency of the United States Government. Neither the United States Government nor the United States Department
of Energy, nor Battelle, nor any of their employees, nor any jurisdiction or organization that has cooperated
in the development of these materials, makes any warranty, express or implied, or assumes any legal liability
or responsibility for the accuracy, completeness, or usefulness or any information, apparatus, product, software,
or process disclosed, or represents that its use would not infringe privately owned rights.

Reference herein to any specific commercial product, process, or service by trade name, trademark, manufacturer,
or otherwise does not necessarily constitute or imply its endorsement, recommendation, or favoring by the United
States Government or any agency thereof, or Battelle Memorial Institute. The views and opinions of authors expressed
herein do not necessarily state or reflect those of the United States Government or any agency thereof.

PACIFIC NORTHWEST NATIONAL LABORATORY operated by BATTELLE for the UNITED STATES DEPARTMENT OF ENERGY
under Contract DE-AC05-76RL01830
-->
<!--
JSON-LD context of a profile, for the data CIMantic Graphs writes with the classes of the
cimantic-graphs.xsl builder (one context per profile, like the cim-profiles contexts).

The context holds:
- the prefix of every namespace the profile uses ('cim' for the profile's ontology), then the
  prefixes of the dataset header (dcat, dct, md, owl, xsd);
- the dcat:Dataset header terms of IEC 61970-552 ed3 ($header_terms);
- one term per profile property that is not a plain string:
    associations, inverse associations and enumerations   {"@type": "@id"}
    attributes and CIM datatypes (a:Domain, CIMUnit values), by the XSD type of their
    values, as the Inst4CIM CGMES context types them      {"@type": "xsd:float"}, "xsd:decimal",
                                                           "xsd:integer", "xsd:boolean", "xsd:dateTime", ...
  The properties are those cimantic-graphs.xsl generates fields for: multi-valued attributes are
  left out, as is everything of the 'Identity' class.

Terms are named as CIMantic Graphs writes the properties: the namespace prefix of the property,
then the class that declares the field and the field name ('cim:ACLineSegment.r'); W3C
properties by bare name ('dct:temporal'). This is the property IRI, except where the UML role
name is not a Python name ('Usage Point' -> 'UsagePoint', IRI 'Register.Usage_Point') or a
profile moves a property onto a subclass of the class that defines it.

Units are not part of a context (JSON-LD 1.1 rejects unknown keys in term definitions); they
belong in a separate qudt:hasUnit vocabulary.

Generation stops on a namespace with no prefix, on an XSD type not in $xsd_types, on a
property typed two ways, and on a dcat/dct property whose type contradicts its header term.
-->
<xsl:stylesheet version="3.0"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
                xmlns:xs="http://www.w3.org/2001/XMLSchema"
                xmlns:a="http://langdale.com.au/2005/Message#"
                xmlns:fn="http://www.w3.org/2005/xpath-functions"
                xmlns:map="http://www.w3.org/2005/xpath-functions/map"
                xmlns:local="urn:local-functions"
                exclude-result-prefixes="xs a fn map local">

    <xsl:output method="text" encoding="utf-8"/>

    <xsl:param name="ontologyURI" as="xs:string" required="yes"/>

    <!-- XML prefix for each namespace a profile may use: the same map as cimantic-graphs.xsl,
         so the context's prefixes are the NAMESPACES of the generated classes. Keep the two in
         sync. The profile's own ontology is always 'cim'. -->
    <xsl:variable name="cim_namespace" as="xs:string" select="concat($ontologyURI, '#')"/>
    <xsl:variable name="prefixes" as="map(xs:string, xs:string)" select="map:merge((
            map {$cim_namespace: 'cim'},
            map {
                'http://iec.ch/TC57/CIM100-European#': 'eu',
                'http://entsoe.eu/CIM/SchemaExtension/3/1#': 'entsoe',
                'http://entsoe.eu/ns/nc#': 'nc',
                'http://GB/placeholder/ext#': 'gb',
                'http://gridappsd.org/CIM/extension#': 'gad',
                'http://epri.com/gmdm/2025#': 'gmdm',
                'http://purl.org/dc/elements/1.1/': 'dc',
                'http://www.w3.org/ns/dcat#': 'dcat',
                'http://purl.org/dc/terms/': 'dcterms'
            }), map {'duplicates': 'use-first'})"/>

    <!-- Namespaces of every class and property in this profile, the ontology first -->
    <xsl:variable name="used_namespaces" as="xs:string*" select="distinct-values((
            $cim_namespace,
            //(@baseClass | @baseProperty)[matches(., '[#/]')] ! local:namespace(.)))"/>

    <!-- Prefixes of the dataset header (IEC 61970-552 ed3) -->
    <xsl:variable name="document_namespaces" as="element(fn:string)*">
        <fn:string key="dcat">http://www.w3.org/ns/dcat#</fn:string>
        <fn:string key="dct">http://purl.org/dc/terms/</fn:string>
        <fn:string key="md">http://iec.ch/TC57/61970-552/ModelDescription/1#</fn:string>
        <fn:string key="owl">http://www.w3.org/2002/07/owl#</fn:string>
        <fn:string key="xsd">http://www.w3.org/2001/XMLSchema#</fn:string>
    </xsl:variable>

    <!-- The dcat:Dataset header terms of IEC 61970-552 ed3 and the ENTSO-E metadata
         specification, typed as in the Inst4CIM CGMES context (their md:FullModel
         counterparts in comments) -->
    <xsl:variable name="header_terms" as="element(fn:map)*">
        <xsl:sequence select="local:term('dct:conformsTo', '@id')"/>              <!-- md:Model.profile -->
        <xsl:sequence select="local:term('dct:issued', 'xsd:dateTime')"/>         <!-- md:Model.created -->
        <xsl:sequence select="local:term('dct:references', '@id')"/>              <!-- md:Model.DependentOn -->
        <xsl:sequence select="local:term('dct:requires', '@id')"/>                <!-- md:Model.DependentOn -->
        <xsl:sequence select="local:term('dct:replaces', '@id')"/>                <!-- md:Model.Supersedes -->
        <xsl:sequence select="local:term('dcat:isVersionOf', '@id')"/>            <!-- md:Model.modelingAuthoritySet -->
        <xsl:sequence select="local:term('dcat:startDate', 'xsd:dateTimeStamp')"/> <!-- md:Model.scenarioTime -->
        <xsl:sequence select="local:term('dcat:endDate', 'xsd:dateTimeStamp')"/>
    </xsl:variable>

    <!-- W3C vocabulary properties are terms by bare name (dct:temporal), not Class.property -->
    <xsl:variable name="w3c_prefixes" as="map(xs:string, xs:string)" select="map {
            'http://www.w3.org/ns/dcat#': 'dcat',
            'http://purl.org/dc/terms/': 'dct'}"/>

    <xsl:template match="a:Catalog">
        <xsl:for-each select="$used_namespaces[not(map:contains($prefixes, .))]">
            <xsl:message terminate="yes">cimantic-graphs-jsonld-context: namespace <xsl:value-of select="."/> has no prefix; add it to $prefixes here and in cimantic-graphs.xsl</xsl:message>
        </xsl:for-each>

        <xsl:variable name="profile_namespaces" as="element(fn:string)*">
            <xsl:for-each select="$used_namespaces">
                <xsl:sort select="if (. eq $cim_namespace) then '' else $prefixes(.)"/>
                <fn:string key="{$prefixes(.)}"><xsl:value-of select="."/></fn:string>
            </xsl:for-each>
        </xsl:variable>

        <xsl:variable name="json">
            <fn:map>
                <fn:map key="@context">
                    <xsl:sequence select="$profile_namespaces"/>
                    <xsl:sequence select="$document_namespaces[not(@key = $profile_namespaces/@key)]"/>
                    <xsl:sequence select="$header_terms"/>
                    <xsl:call-template name="property_terms"/>
                </fn:map>
            </fn:map>
        </xsl:variable>
        <xsl:value-of select="local:json($json/fn:map, '')"/>
        <xsl:text>&#10;</xsl:text>
    </xsl:template>

    <!-- One term per typed property, sorted by Class.property -->
    <xsl:template name="property_terms">
        <xsl:variable name="classes" select="(a:Root | a:ComplexType | a:CompoundType)[@name ne 'Identity']"/>
        <xsl:variable name="properties" as="element()*" select="
                $classes/(a:Simple | a:Domain | a:Enumerated)[local:single_valued(.)],
                $classes/(a:Instance | a:Reference | a:Compound),
                //(a:InverseReference | a:InverseInstance)[local:local_name(@basePropertyClass) = $classes/@name]"/>

        <xsl:for-each-group select="$properties" group-by="local:term_name(.)">
            <xsl:sort select="substring-after(current-grouping-key(), ':')"/>
            <xsl:variable name="term" select="current-grouping-key()"/>
            <xsl:variable name="datatypes" select="distinct-values(current-group() ! local:datatype(.))"/>
            <xsl:if test="count($datatypes) gt 1">
                <xsl:message terminate="yes">cimantic-graphs-jsonld-context: <xsl:value-of select="$term"/> is typed both <xsl:value-of select="string-join($datatypes, ' and ')"/></xsl:message>
            </xsl:if>
            <xsl:variable name="header_type" select="$header_terms[@key = $term]/fn:string"/>
            <xsl:choose>
                <!-- A header term keeps its header typing; a plain string (dct:issued) takes it -->
                <xsl:when test="exists($header_type)">
                    <xsl:if test="exists($datatypes) and $datatypes ne $header_type">
                        <xsl:message terminate="yes">cimantic-graphs-jsonld-context: <xsl:value-of select="$term"/>: the profile types it <xsl:value-of select="$datatypes"/>, the dataset header <xsl:value-of select="$header_type"/></xsl:message>
                    </xsl:if>
                </xsl:when>
                <xsl:when test="exists($datatypes)">
                    <xsl:sequence select="local:term($term, $datatypes)"/>
                </xsl:when>
            </xsl:choose>
        </xsl:for-each-group>
    </xsl:template>

    <!-- JSON text of the XML representation of JSON (fn:map and fn:string only), laid out as
         Python's json.dumps(indent=2); xml-to-json() would also escape every '/' -->
    <xsl:function name="local:json" as="xs:string">
        <xsl:param name="node" as="element()"/>
        <xsl:param name="indent" as="xs:string"/>
        <xsl:choose>
            <xsl:when test="$node[self::fn:string]">
                <xsl:sequence select="local:json_string($node)"/>
            </xsl:when>
            <xsl:when test="$node[self::fn:map] and empty($node/*)">{}</xsl:when>
            <xsl:when test="$node[self::fn:map]">
                <xsl:variable name="inner" select="concat($indent, '  ')"/>
                <xsl:variable name="members" select="$node/* ! concat($inner, local:json_string(@key), ': ', local:json(., $inner))"/>
                <xsl:sequence select="concat('{&#10;', string-join($members, ',&#10;'), '&#10;', $indent, '}')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message terminate="yes">cimantic-graphs-jsonld-context: cannot write <xsl:value-of select="name($node)"/> as JSON</xsl:message>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <xsl:function name="local:json_string" as="xs:string">
        <xsl:param name="text" as="xs:string"/>
        <xsl:sequence select="concat('&quot;', replace(replace($text, '\\', '\\\\'), '&quot;', '\\&quot;'), '&quot;')"/>
    </xsl:function>

    <!-- A term definition {"<name>": {"@type": "<datatype>"}} in the XML representation of JSON -->
    <xsl:function name="local:term" as="element(fn:map)">
        <xsl:param name="name" as="xs:string"/>
        <xsl:param name="datatype" as="xs:string"/>
        <fn:map key="{$name}">
            <fn:string key="@type"><xsl:value-of select="$datatype"/></fn:string>
        </fn:map>
    </xsl:function>

    <!-- The term of a property, as CIMantic Graphs names it: 'cim:ACLineSegment.r' (the class
         whose dataclass declares the field, and the field name), or 'dct:temporal' for a W3C
         property. An inverse end is a field of the class at its basePropertyClass. -->
    <xsl:function name="local:term_name" as="xs:string">
        <xsl:param name="property" as="element()"/>
        <xsl:variable name="namespace" select="local:namespace($property/@baseProperty)"/>
        <xsl:variable name="field" select="local:sanitize_name($property/@name, ($property/@type, $property/@xstype, 'unknown')[1])"/>
        <xsl:choose>
            <xsl:when test="map:contains($w3c_prefixes, $namespace)">
                <xsl:sequence select="concat($w3c_prefixes($namespace), ':', $field)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:variable name="class" select="if ($property[self::a:InverseReference or self::a:InverseInstance])
                        then local:local_name($property/@basePropertyClass) else $property/../@name"/>
                <xsl:sequence select="concat($prefixes($namespace), ':', local:sanitize_name($class, $class), '.', $field)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- Python name of a class or field: a copy of local:sanitize_name in cimantic-graphs.xsl -->
    <xsl:variable name="python_keywords" as="xs:string*" select="(
            'and', 'as', 'assert', 'break', 'class', 'continue', 'def', 'del',
            'elif', 'else', 'except', 'finally', 'for', 'from', 'global', 'if',
            'import', 'in', 'is', 'lambda', 'nonlocal', 'not', 'or', 'pass',
            'raise', 'return', 'try', 'while', 'with', 'yield'
        )"/>

    <xsl:function name="local:sanitize_name" as="xs:string">
        <xsl:param name="name" as="xs:string"/>
        <xsl:param name="type" as="xs:string"/>
        <xsl:variable name="clean_name" select="if (contains($name, 'EAID_')) then $type else replace($name, '[^a-zA-Z0-9_]', '')"/>
        <xsl:variable name="safe_name" select="if (string-length($clean_name) = 0) then 'unnamed' else $clean_name"/>
        <xsl:variable name="prefixed_name" select="if (matches($safe_name, '^[0-9]')) then concat('_', $safe_name) else $safe_name"/>
        <xsl:sequence select="if ($prefixed_name = $python_keywords) then concat('_', $prefixed_name) else $prefixed_name"/>
    </xsl:function>

    <!-- The JSON-LD @type of a property, or () for a plain string -->
    <xsl:function name="local:datatype" as="xs:string?">
        <xsl:param name="property" as="element()"/>
        <xsl:choose>
            <!-- Attributes and CIM datatypes (CIMUnit values) by their XSD type -->
            <xsl:when test="$property[self::a:Simple or self::a:Domain]">
                <xsl:sequence select="local:xsd_datatype($property)"/>
            </xsl:when>
            <!-- Associations, their inverses, compounds and enumerations -->
            <xsl:otherwise>@id</xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- The XSD datatype of an attribute's values ('xsd:float', 'xsd:dateTime', ...), as the
         Inst4CIM CGMES context types them; () for a string, the JSON-LD default -->
    <xsl:variable name="xsd_types" as="xs:string*" select="(
            'float', 'double', 'decimal', 'integer', 'boolean',
            'dateTime', 'dateTimeStamp', 'date', 'time', 'duration', 'gMonthDay', 'anyURI')"/>

    <xsl:function name="local:xsd_datatype" as="xs:string?">
        <xsl:param name="property" as="element()"/>
        <xsl:choose>
            <xsl:when test="$property/@xstype = 'string'"/>
            <xsl:when test="$property/@xstype = $xsd_types">
                <xsl:sequence select="concat('xsd:', $property/@xstype)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:message terminate="yes">cimantic-graphs-jsonld-context: <xsl:value-of select="$property/../@name"/>.<xsl:value-of select="$property/@name"/> has XSD type '<xsl:value-of select="$property/@xstype"/>'; add it to $xsd_types</xsl:message>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- cimantic-graphs.xsl generates fields only for single-valued attributes -->
    <xsl:function name="local:single_valued" as="xs:boolean">
        <xsl:param name="property" as="element()"/>
        <xsl:sequence select="$property/@maxOccurs = ('0', '1')"/>
    </xsl:function>

    <!-- Namespace of a class or property IRI: everything up to its last '#' or '/'.
         CIM namespaces end in '#', Dublin Core ones (http://purl.org/dc/terms/) in '/'. -->
    <xsl:function name="local:namespace" as="xs:string">
        <xsl:param name="iri" as="xs:string"/>
        <xsl:sequence select="replace($iri, '^(.*[#/]).*$', '$1')"/>
    </xsl:function>

    <!-- Local name of a class or property IRI: everything after its last '#' or '/' -->
    <xsl:function name="local:local_name" as="xs:string">
        <xsl:param name="iri" as="xs:string"/>
        <xsl:sequence select="replace($iri, '^.*[#/]', '')"/>
    </xsl:function>

</xsl:stylesheet>
