<?xml version="1.0" encoding="UTF-8"?>
<!--
    This builder is released under a BSD-3 license as part of the CIMantic Graphs library developed by PNNL.
        
    This software was created under a project sponsored by the U.S. Department of Energy’s Office of Electricity, 
    an agency of the United States Government. Neither the United States Government nor the United States Department 
    of Energy, nor Battelle, nor any of their employees, nor any jurisdiction or organization that has cooperated 
    in the development of these materials, makes any warranty, express or implied, or assumes any legal liability 
    or responsibility for the accuracy, completeness, or usefulness or any information, apparatus, product, software, 
    or process disclosed, or represents that its use would not infringe privately owned rights.
    
    Reference herein to any specific commercial product, process, or service by trade name, trademark, manufacturer, 
    or otherwise does not necessarily constitute or imply its endorsement, recommendation, or favoring by the United 
    States Government or any agency thereof, or Battelle Memorial Institute. The views and opinions of authors expressed 
    herein do not necessarily state or reflect those of the United States Government or any agency thereof.
    
    PACIFIC NORTHWEST NATIONAL LABORATORY
    operated by BATTELLE
    for the UNITED STATES DEPARTMENT OF ENERGY 
    under Contract DE-AC05-76RL01830
-->
    <xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    xmlns:a="http://langdale.com.au/2005/Message#"
    xmlns:sawsdl="http://www.w3.org/ns/sawsdl"
    xmlns:fn="http://www.w3.org/2005/xpath-functions"
    xmlns:local="urn:local-functions"
    xmlns="http://langdale.com.au/2009/Indent"
    exclude-result-prefixes="xs fn local">

    <xsl:output indent="yes" method="xml" encoding="utf-8"/>

    <!-- Parameters with default values -->
    <xsl:param name="version" as="xs:string?" select="()"/>
    <xsl:param name="baseURI" as="xs:string" required="yes"/>
    <xsl:param name="ontologyURI" as="xs:string" required="yes"/>
    <xsl:param name="envelope" as="xs:string" select="'Profile'"/>
    <xsl:param name="package" as="xs:string" select="'au.com.langdale.cimtool.generated'"/>

    <!-- Key for tracing parent-child inheritance -->
    <xsl:key name="classes-by-super" match="a:Root | a:ComplexType" use="a:SuperType/@name"/>

    <!-- Key for finding inverse references by target class -->
    <xsl:key name="inverse-references" match="a:InverseReference" use="substring-after(@inverseBasePropertyClass, '#')"/>

    <xsl:variable name="python-keywords" as="xs:string*" select="(
            'and', 'as', 'assert', 'break', 'class', 'continue', 'def', 'del', 
            'elif', 'else', 'except', 'finally', 'for', 'from', 'global', 'if', 
            'import', 'in', 'is', 'lambda', 'nonlocal', 'not', 'or', 'pass', 
            'raise', 'return', 'try', 'while', 'with', 'yield'
        )"/>

    <!-- Template for top-level item in schema file -->
    <xsl:template match="a:Catalog">
        <document>
            <!-- Header imports -->
            <xsl:call-template name="generate-imports"/>
            
            <!-- Documentation -->
            <xsl:call-template name="generate-documentation"/>
            
            <!-- Constants -->
            <item>BASE_URI = '<xsl:value-of select="$baseURI"/>'</item>
            <item>ONTOLOGY_URI = '<xsl:value-of select="$ontologyURI"/>#'</item>
            <item/>
            
            <!-- Process classes hierarchically -->
            <xsl:apply-templates select="a:Root[not(a:SuperType)] | a:ComplexType[not(a:SuperType)]" mode="super"/>
            
            <!-- Process enumerations -->
            <xsl:apply-templates select="a:EnumeratedType" mode="enumeration"/>
            
            <!-- Process primitives -->
            <xsl:apply-templates select="a:SimpleType" mode="units"/>
            
            <!-- Process compounds -->
            <xsl:apply-templates select="a:CompoundType" mode="super"/>
        </document>
    </xsl:template>

    <!-- Generate imports section -->
    <xsl:template name="generate-imports">
        <item>from __future__ import annotations</item>
        <item>import logging</item>
        <item>from dataclasses import dataclass, field</item>
        <item>from typing import Optional</item>
        <item>from enum import Enum</item>
        <item>from cimgraph.data_profile.identity import Identity, CIMStereotype, stereotype</item>
        <item>from cimgraph.data_profile.units import CIMUnit, UnitSymbol, UnitMultiplier</item>
        <item>_log = logging.getLogger(__name__)</item>
    </xsl:template>

    <!-- Generate documentation section -->
    <xsl:template name="generate-documentation">
        <list begin="'''" indent="    " end="'''">
            <item>Annotated CIMantic Graphs data profile for <xsl:value-of select="$envelope"/></item>
            <item>Generated by CIMTool http://cimtool.org</item>
        </list>
        <item/>
    </xsl:template>

    <!-- Template for top-level classes with no inheritance -->
    <xsl:template match="a:Root | a:ComplexType | a:CompoundType" mode="super">
        <xsl:call-template name="generate-stereotype"/>
        
        <xsl:variable name="class-name" select="local:sanitize-name(@name, @name)"/>
        
        <item>@dataclass(repr=False)</item>
        <item>class <xsl:value-of select="$class-name"/>(Identity):</item>
        
        <xsl:call-template name="generate-class-docstring"/>
        
        <!-- Process inverse references first (they come from other classes) -->
        <xsl:apply-templates select="key('inverse-references', @name)" mode="inverse-association"/>
        
        <!-- Process attributes -->
        <xsl:apply-templates select="a:Simple" mode="simple-attribute"/>
        <xsl:apply-templates select="a:Domain | a:Enumerated" mode="attribute"/>
        <xsl:apply-templates select="a:Instance | a:Reference" mode="association"/>
        
        <!-- Process child classes -->
        <xsl:apply-templates select="key('classes-by-super', @name)" mode="lower"/>
    </xsl:template>

    <!-- Template for lower level classes -->
    <xsl:template match="a:Root | a:ComplexType" mode="lower">
        <xsl:if test=". is key('classes-by-super', a:SuperType/@name)[1]">
            <xsl:for-each select="key('classes-by-super', a:SuperType/@name)">
                <xsl:call-template name="generate-stereotype"/>
                
                <item>@dataclass(repr=False)</item>
                
                <xsl:variable name="class-name" select="local:sanitize-name(@name, @name)"/>
                <item>class <xsl:value-of select="$class-name"/>(<xsl:value-of select="a:SuperType/@name"/>):</item>
                
                <xsl:call-template name="generate-class-docstring"/>
                
                <!-- Process inverse references first (they come from other classes) -->
                <xsl:apply-templates select="key('inverse-references', @name)" mode="inverse-association"/>
                
                <!-- Process attributes -->
                <xsl:apply-templates select="a:Simple" mode="simple-attribute"/>
                <xsl:apply-templates select="a:Domain | a:Enumerated" mode="attribute"/>
                <xsl:apply-templates select="a:Instance | a:Reference" mode="association"/>
                
                <!-- Process child classes -->
                <xsl:apply-templates select="key('classes-by-super', @name)" mode="lower"/>
            </xsl:for-each>
        </xsl:if>
    </xsl:template>

    <!-- Generate stereotype decorator -->
    <xsl:template name="generate-stereotype">
        <xsl:variable name="stereotype-label" select="a:Stereotype/@label"/>
        <!-- Parse Stereotype -->
        <xsl:choose>
            <xsl:when test="a:Stereotype[@label='Description']">
                <item>@stereotype(CIMStereotype.Description)</item>
            </xsl:when>
            <xsl:when test="a:Stereotype[@label='Concrete']">
                <item>@stereotype(CIMStereotype.Concrete)</item>
            </xsl:when>
            <xsl:when test="a:Stereotype[@label='ByReference']">
                <item>@stereotype(CIMStereotype.ByReference)</item>
            </xsl:when>
            <xsl:when test="a:Stereotype/@label">
                <item>@stereotype(CIMStereotype.<xsl:value-of select="a:Stereotype/@label"/>)</item>
            </xsl:when>
        </xsl:choose>
    </xsl:template>

    <!-- Generate class docstring -->
    <xsl:template name="generate-class-docstring">
        <xsl:if test="a:Comment">
            <list begin="    '''" indent="    " end="    '''">
                <xsl:for-each select="a:Comment">
                    <wrap width="70">
                        <xsl:value-of select="."/>
                    </wrap>
                </xsl:for-each>
            </list>
            <item/>
        </xsl:if>
    </xsl:template>

    <!-- Template for processing inverse references -->
    <xsl:template match="a:InverseReference" mode="inverse-association">
        <xsl:variable name="field-name" select="local:sanitize-name(@name, (@type, 'unknown')[1])"/>
        <xsl:variable name="target-type" select="@type"/>
        <xsl:variable name="inverse-property" select="substring-after(@inverseBaseProperty, '#')"/>
        
        <list begin="" indent="    " end="">
            <xsl:choose>
                <xsl:when test="(@maxOccurs castable as xs:integer and xs:integer(@maxOccurs) le 1) or @maxOccurs = '1' or @maxOccurs = '0'">
                    <item>
                        <xsl:value-of select="$field-name"/>: Optional[<xsl:value-of select="$target-type"/>] = field( 
                    </item>
                    <list begin="" indent="    " end="">
                        <item>default=None,</item>
                    </list>
                </xsl:when>
                <xsl:otherwise>
                    <item>
                        <xsl:value-of select="$field-name"/>: list[<xsl:value-of select="$target-type"/>] = field(
                    </item>
                    <list begin="" indent="    " end="">
                        <item>default_factory=list,</item>
                    </list>
                </xsl:otherwise>
            </xsl:choose>
            
            <list begin="" indent="    " end="">
                <item>metadata={</item>
                <xsl:call-template name="generate-inverse-association-metadata"/>
                <item>})</item>
            </list>
            
            <xsl:if test="a:Comment">
                <list begin="'''" indent="" end="'''">
                    <xsl:for-each select="a:Comment">
                        <wrap width="66">
                            <xsl:value-of select="."/>
                        </wrap>
                    </xsl:for-each>
                </list>
            </xsl:if>
            <item/>
        </list>
    </xsl:template>

    <!-- Template for Domain attributes with datatypes -->
    <xsl:template match="a:Domain | a:Enumerated" mode="attribute">
        <xsl:if test="(@maxOccurs castable as xs:integer and xs:integer(@maxOccurs) le 1) or @maxOccurs = '1' or @maxOccurs = '0'">
            <xsl:variable name="python-type" select="local:get-python-type(@xstype)"/>
            <xsl:variable name="field-name" select="local:sanitize-name(@name, (@type, 'unknown')[1])"/>
            
            <list begin="" indent="    " end="">
                <item>
                    <xsl:value-of select="$field-name"/>: Optional[
                    <xsl:choose>
                        <xsl:when test="$python-type = 'str'">
                            <xsl:value-of select="(@type, 'str')[1]"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="$python-type"/> | <xsl:value-of select="(@type, 'str')[1]"/>
                        </xsl:otherwise>
                    </xsl:choose>
                    ] = field(
                </item>
                
                <list begin="" indent="    " end="">
                    <item>default=None,</item>
                    <item>metadata={</item>
                    <xsl:call-template name="generate-attribute-metadata"/>
                    <item>})</item>
                </list>
                
                <xsl:if test="a:Comment">
                    <list begin="'''" indent="" end="'''">
                        <xsl:for-each select="a:Comment">
                            <wrap width="66">
                                <xsl:value-of select="."/>
                            </wrap>
                        </xsl:for-each>
                    </list>
                </xsl:if>
                <item/>
            </list>
        </xsl:if>
    </xsl:template>

    <!-- Template for Simple attributes with primitive datatypes -->
    <xsl:template match="a:Simple" mode="simple-attribute">
        <xsl:if test="(@maxOccurs castable as xs:integer and xs:integer(@maxOccurs) le 1) or @maxOccurs = '1' or @maxOccurs = '0'">
            <xsl:variable name="python-type" select="local:get-python-type(@xstype)"/>
            <xsl:variable name="field-name" select="local:sanitize-name(@name, (@xstype, 'unknown')[1])"/>
            
            <list begin="" indent="    " end="">
                <item>
                    <xsl:value-of select="$field-name"/>: Optional[<xsl:value-of select="$python-type"/>] = field(
                </item>
                
                <list begin="" indent="    " end="">
                    <item>default=None,</item>
                    <item>metadata={</item>
                    <xsl:call-template name="generate-attribute-metadata"/>
                    <item>})</item>
                </list>
                
                <xsl:if test="a:Comment">
                    <list begin="'''" indent="" end="'''">
                        <xsl:for-each select="a:Comment">
                            <wrap width="66">
                                <xsl:value-of select="."/>
                            </wrap>
                        </xsl:for-each>
                    </list>
                </xsl:if>
                <item/>
            </list>
        </xsl:if>
    </xsl:template>

    <!-- Template for associations with other classes -->
    <xsl:template match="a:Instance | a:Reference" mode="association">
        <xsl:variable name="field-name" select="local:sanitize-name(@name, (@type, 'unknown')[1])"/>
        
        <list begin="" indent="    " end="">
            <xsl:choose>
                <xsl:when test="(@maxOccurs castable as xs:integer and xs:integer(@maxOccurs) le 1) or @maxOccurs = '1' or @maxOccurs = '0'">
                    <item>
                        <xsl:value-of select="$field-name"/>: Optional[<xsl:value-of select="(@type, 'object')[1]"/>] = field(
                    </item>
                    <list begin="" indent="    " end="">
                        <item>default=None,</item>
                    </list>
                </xsl:when>
                <xsl:otherwise>
                    <item>
                        <xsl:value-of select="$field-name"/>: list[<xsl:value-of select="(@type, 'object')[1]"/>] = field(
                    </item>
                    <list begin="" indent="    " end="">
                        <item>default_factory=list,</item>
                    </list>
                </xsl:otherwise>
            </xsl:choose>
            
            <list begin="" indent="    " end="">
                <item>metadata={</item>
                <xsl:call-template name="generate-association-metadata"/>
                <item>})</item>
            </list>
            
            <xsl:if test="a:Comment">
                <list begin="'''" indent="" end="'''">
                    <xsl:for-each select="a:Comment">
                        <wrap width="66">
                            <xsl:value-of select="."/>
                        </wrap>
                    </xsl:for-each>
                </list>
            </xsl:if>
            <item/>
        </list>
    </xsl:template>

    <!-- Template for enumerations -->
    <xsl:template match="a:EnumeratedType" mode="enumeration">
        <xsl:variable name="enum-name" select="local:sanitize-name(@name, @name)"/>
        
        <item>@stereotype(CIMStereotype.Enumeration)</item>
        <item>class <xsl:value-of select="$enum-name"/>(Enum):</item>
        
        <xsl:call-template name="generate-class-docstring"/>
        
        <xsl:for-each select="a:EnumeratedValue">
            <xsl:variable name="value-name" select="local:sanitize-name(@name, @name)"/>
            <list begin="" indent="    " end="">
                <item><xsl:value-of select="$value-name"/> = '<xsl:value-of select="$value-name"/>'</item>
                <xsl:if test="a:Comment">
                    <list begin="'''" indent="" end="'''">
                        <xsl:for-each select="a:Comment">
                            <wrap width="66">
                                <xsl:value-of select="."/>
                            </wrap>
                        </xsl:for-each>
                    </list>
                </xsl:if>
                <item/>
            </list>
        </xsl:for-each>
    </xsl:template>

    <!-- Template for CIM Units as SimpleType -->
    <xsl:template match="a:SimpleType" mode="units">
        <item>@stereotype(CIMStereotype.CIMDatatype)</item>
        <item>@dataclass(repr=False)</item>
        <item>class <xsl:value-of select="@name"/>(CIMUnit):</item>
        
        <xsl:call-template name="generate-class-docstring"/>
        
        <!-- Process Simple elements -->
        <xsl:for-each select="a:Simple">
            <xsl:variable name="python-type" select="local:get-python-type(@xstype)"/>
            <list begin="" indent="    " end="">
                <item><xsl:value-of select="@name"/>: <xsl:value-of select="$python-type"/> = field(default=None)</item>
            </list>
        </xsl:for-each>
        
        <!-- Process multiplier fields -->
        <xsl:for-each select="a:Enumerated[@name='multiplier']">
            <xsl:variable name="multiplier-const" select="if (@constant = '' or @constant = 'none') then 'none' else @constant"/>
            <list begin="" indent="    " end="">
                <item><xsl:value-of select="@name"/>: <xsl:value-of select="@type"/> = field(default=<xsl:value-of select="@type"/>.<xsl:value-of select="$multiplier-const"/>)</item>
            </list>
        </xsl:for-each>
        
        <!-- Process unit fields as properties -->
        <xsl:for-each select="a:Enumerated[@name='unit']">
            <xsl:variable name="unit-const" select="if (@constant = '' or @constant = 'none') then 'none' else @constant"/>
            <list begin="" indent="    " end="">
                <item>@property  # read-only</item>
                <item>def <xsl:value-of select="@name"/>(self):</item>
                <list begin="" indent="    " end="">
                    <item>return <xsl:value-of select="@type"/>.<xsl:value-of select="$unit-const"/></item>
                </list>
            </list>
        </xsl:for-each>
        
        <!-- Add __init__ method -->
        <xsl:variable name="unit-const" select="if (a:Enumerated[@name='unit']/@constant = '' or a:Enumerated[@name='unit']/@constant = 'none') then 'none' else a:Enumerated[@name='unit']/@constant"/>
        <list begin="" indent="    " end="">
            <item>def __init__(self, value, input_unit: str='<xsl:value-of select="$unit-const"/>', input_multiplier: str=None):</item>
            <list begin="" indent="    " end="">
                <item>self.__pint__(value=value, input_unit=input_unit, input_multiplier=input_multiplier)</item>
            </list>
        </list>
        
        <item/>
    </xsl:template>

    <!-- Generate attribute metadata -->
    <xsl:template name="generate-attribute-metadata">
        <item>'type': '<xsl:value-of select="if (a:Stereotype/@label) then a:Stereotype/@label else 'Attribute'"/>',</item>
        <item>'minOccurs': '<xsl:value-of select="(@minOccurs, '0')[1]"/>',</item>
        <item>'maxOccurs': '<xsl:value-of select="(@maxOccurs, '1')[1]"/>',</item>
        <item>'namespace': '<xsl:value-of select="substring-before((@baseProperty, '#')[1],'#')"/>#'</item>
    </xsl:template>

    <!-- Generate association metadata -->
    <xsl:template name="generate-association-metadata">
        <item>'type': '<xsl:value-of select="if (a:Stereotype/@label) then a:Stereotype/@label else 'Association'"/>',</item>
        <item>'minOccurs': '<xsl:value-of select="(@minOccurs, '0')[1]"/>',</item>
        <item>'maxOccurs': '<xsl:value-of select="(@maxOccurs, '1')[1]"/>',</item>
        <item>'inverse': '<xsl:value-of select="substring-after((@inverseBaseProperty, '#')[1],'#')"/>',</item>
        <item>'namespace': '<xsl:value-of select="substring-before((@baseProperty, '#')[1],'#')"/>#'</item>
    </xsl:template>

    <!-- Generate inverse association metadata -->
    <xsl:template name="generate-inverse-association-metadata">
        <item>'type': '<xsl:value-of select="if (a:Stereotype/@label) then a:Stereotype/@label else 'Association'"/>',</item>
        <item>'minOccurs': '<xsl:value-of select="(@minOccurs, '0')[1]"/>',</item>
        <item>'maxOccurs': '<xsl:value-of select="(@maxOccurs, '1')[1]"/>',</item>
        <item>'inverse': '<xsl:value-of select="substring-after(@inverseBaseProperty, '#')"/>',</item>
        <item>'namespace': '<xsl:value-of select="substring-before(@baseProperty,'#')"/>#'</item>
    </xsl:template>

    <!-- Function to get Python type mapping using explicit choose/when -->
    <xsl:function name="local:get-python-type" as="xs:string">
        <xsl:param name="xstype" as="xs:string?"/>
        <xsl:choose>
            <xsl:when test="not($xstype) or string-length($xstype) = 0">str</xsl:when>
            <xsl:when test="$xstype = 'string' or $xstype = 'String'">str</xsl:when>
            <xsl:when test="$xstype = 'integer' or $xstype = 'Integer' or $xstype = 'int'">int</xsl:when>
            <xsl:when test="$xstype = 'float' or $xstype = 'Float'">float</xsl:when>
            <xsl:when test="$xstype = 'double' or $xstype = 'Double'">float</xsl:when>
            <xsl:when test="$xstype = 'boolean' or $xstype = 'Boolean'">bool</xsl:when>
            <xsl:otherwise>str</xsl:otherwise>
        </xsl:choose>
    </xsl:function>

    <!-- Function to sanitize names with proper null handling -->
    <xsl:function name="local:sanitize-name" as="xs:string">
        <xsl:param name="name" as="xs:string"/>
        <xsl:param name="type" as="xs:string"/>
        
        <!-- Handle EAID_ prefixed names -->
        <xsl:variable name="clean-name" select="
            if (contains($name, 'EAID_')) then $type 
            else replace($name, '[^a-zA-Z0-9_]', '')"/>
        
        <!-- Handle empty names -->
        <xsl:variable name="safe-name" select="
            if (string-length($clean-name) = 0) then 'unnamed'
            else $clean-name"/>
        
        <!-- Handle names starting with digits -->
        <xsl:variable name="prefixed-name" select="
            if (matches($safe-name, '^[0-9]')) then concat('_', $safe-name)
            else $safe-name"/>
        
        <!-- Handle Python keywords -->
        <xsl:sequence select="
            if ($prefixed-name = $python-keywords) then concat('_', $prefixed-name)
            else $prefixed-name"/>
    </xsl:function>
</xsl:stylesheet>