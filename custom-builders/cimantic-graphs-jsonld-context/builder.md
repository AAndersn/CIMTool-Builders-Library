# cimantic-graphs-jsonld-context.xsl

A custom builder shared with UCAIug by Pacific Northwest National Laboratory. This is a community provided builder that does not ship with CIMTool.

## Builder Description

The **[cimantic-graphs-jsonld-context.xsl](cimantic-graphs-jsonld-context.xsl)** builder produces the [JSON-LD](https://www.w3.org/TR/json-ld11/) context of a profile, for the JSON-LD data that the [CIMantic Graphs](https://github.com/PNNL-CIM-Tools/CIM-Graph) library reads and writes with the classes of the [cimantic-graphs.xsl](../../shipped-builders/cimantic-graphs/builder.md) builder. It is a companion to that builder: run both on the same profile.

The context holds:

- the prefix of every namespace the profile uses (`cim` for the profile's ontology; the same prefixes as the `NAMESPACES` of the cimantic-graphs classes), then the prefixes of the dataset header (`dcat`, `dct`, `md`, `owl`, `xsd`);
- the `dcat:Dataset` header terms of IEC 61970-552 ed3 (`dct:conformsTo`, `dct:issued`, `dcat:startDate`, ...);
- one term per profile property that is not a plain string: associations, their inverse ends and enumerations are `{"@type": "@id"}`; attributes and CIM datatypes (the `CIMUnit` values of CIMantic Graphs) take the XSD type of their values (`xsd:float`, `xsd:decimal` for `Money`, `xsd:integer`, `xsd:boolean`, `xsd:dateTime`, `xsd:date`, `xsd:duration`, `xsd:gMonthDay`, ...). The properties are those cimantic-graphs.xsl generates fields for, so multi-valued attributes and the `Identity` class are left out.

The terms and their types follow the [Inst4CIM-KG](https://github.com/Sveino/Inst4CIM-KG) CGMES context (`rdf-improved/cim-context-old.jsonld`): on the CGMES 3.0 profiles, every term the two contexts share has the same `@type`. Unlike Inst4CIM, which keeps the rest of the property metadata in RDFS vocabularies (`rdfs-improved/CGMES/ttl`), everything here is JSON.

Terms are named as CIMantic Graphs writes the properties: the property's namespace prefix, then the class that declares the field and the field name (`cim:ACLineSegment.r`). W3C properties are named by bare name (`dct:temporal`). This is the property IRI except where the UML role name is not a Python name (the role `Usage Point` becomes the field `UsagePoint`) or a profile moves a property onto a subclass of the class that defines it.

The context carries no units: JSON-LD 1.1 rejects unknown keys in term definitions, so units belong in a separate `qudt:hasUnit` vocabulary.

Generation stops with a message on a namespace that has no prefix (add it to `$prefixes` in this builder and in cimantic-graphs.xsl), on an XSD type the builder does not know (add it to `$xsd_types`), on a property typed two ways, and on a `dcat`/`dct` property whose type contradicts its header term.

Below is part of the context generated for the CGMES 3.0 Topology profile:

```json
{
  "@context": {
    "cim": "http://iec.ch/TC57/CIM100#",
    "eu": "http://iec.ch/TC57/CIM100-European#",
    "dcat": "http://www.w3.org/ns/dcat#",
    "dct": "http://purl.org/dc/terms/",
    "md": "http://iec.ch/TC57/61970-552/ModelDescription/1#",
    "owl": "http://www.w3.org/2002/07/owl#",
    "xsd": "http://www.w3.org/2001/XMLSchema#",
    "dct:conformsTo": {
      "@type": "@id"
    },
    "dct:issued": {
      "@type": "xsd:dateTime"
    },
    "cim:BaseVoltage.TopologicalNode": {
      "@type": "@id"
    },
    "cim:ConnectivityNode.TopologicalNode": {
      "@type": "@id"
    },
    "cim:TopologicalNode.BaseVoltage": {
      "@type": "@id"
    }
  }
}
```

The builder can also be run without the CIMTool user interface, with the CIMTool command line interface:

```bash
java -cp <CIMTool classpath> au.com.langdale.profiles.cl.CIMToolCLI --project-dir MyProject \
     --profile MyProject/Profiles/MyProfile.owl \
     --xslt cimantic-graphs-jsonld-context.xsl --output-ext context.jsonld
```

## XSLT Version

This builder is XSLT 3.0 compliant.

## Author

Alex A. Anderson [@aandersn] on behalf of UCAIug.

## Submission Date

24-Nov-2026

## Builder NTE Configuration

The builder should be configured as a `TEXT` transform with the extension `context.jsonld`, which names the output of `MyProfile.owl` `MyProfile.context.jsonld`.

>*NOTE: </br>CIMTool requires that file extensions be unique and will prevent you from entering an extension already assigned to a builder. This is because an artifact's name is derived by concatenating the base name of the CIMTool ```.owl``` profile with the file extension assigned to the builder. Therefore, a unique file extension must be assigned to each builder when imported. The file extension for a builder can be modified later from within the "Maintain XSLT Transform Builders" screen.*

## License

This builder is released under a [BSD-3](https://github.com/PNNL-CIM-Tools/CIM-Graph/blob/main/LICENSE) license as part of the CIMantic Graphs library developed by PNNL.

This software was created under a project sponsored by the U.S. Department of Energy’s Office of Electricity, an agency of the United States Government. Neither the United States Government nor the United States Department of Energy, nor Battelle, nor any of their employees, nor any jurisdiction or organization that has cooperated in the development of these materials, makes any warranty, express or implied, or assumes any legal liability or responsibility for the accuracy, completeness, or usefulness or any information, apparatus, product, software, or process disclosed, or represents that its use would not infringe privately owned rights.

Reference herein to any specific commercial product, process, or service by trade name, trademark, manufacturer, or otherwise does not necessarily constitute or imply its endorsement, recommendation, or favoring by the United States Government or any agency thereof, or Battelle Memorial Institute. The views and opinions of authors expressed herein do not necessarily state or reflect those of the United States Government or any agency thereof.

PACIFIC NORTHWEST NATIONAL LABORATORY

operated by BATTELLE for the

UNITED STATES DEPARTMENT OF ENERGY

under Contract DE-AC05-76RL01830
