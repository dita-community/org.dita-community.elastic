<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:local="urn:ns:localfunctions"
  xmlns:fn="http://www.w3.org/2005/xpath-functions" exclude-result-prefixes="xs local fn"
  version="3.0" expand-text="yes">

  <!-- =========================================================
       Generates Elasticsearch JSON documents from DITA
       documents suitable for ingest using the Elasticsearch
       bulk ingest facility.
       
       In the bulk ingest, each JSON document is a single 
       line terminated by a newline character.
       
       ========================================================= -->

  <xsl:output method="text"/>

  <xsl:template match="/" priority="10">
    <xsl:variable name="docid" as="xs:string" select="base-uri(.)"/>
    <xsl:variable name="resultData" as="item()*">
      <fn:array>
        <xsl:apply-templates>
          <xsl:with-param name="docid" as="xs:string" tunnel="yes" select="$docid"/>
        </xsl:apply-templates>
      </fn:array>
    </xsl:variable>
    <xsl:sequence select="$resultData"/>
  </xsl:template>

  <xsl:template match="*[@class]" as="item()*">
    <xsl:param name="docid" as="xs:string" tunnel="yes"/>
    <xsl:variable name="jsonXml" as="node()*">
      <fn:map>
        <fn:string key="docid">{$docid}</fn:string>
        <fn:string key="nodeid">{local:getNodeId(.)}</fn:string>
        <fn:string key="parent">{local:getNodeId(..)}</fn:string>
        <fn:string key="tagname">{local-name(.)}</fn:string>
        <fn:string key="namespace">{namespace-uri(.)}</fn:string>
        <xsl:apply-templates mode="ditaClass" select="@class"/>
        <fn:map key="attributes">
          <xsl:apply-templates select="@*"/>
        </fn:map>
        <fn:string key="text">{normalize-space(.)}</fn:string>
      </fn:map>
    </xsl:variable>
    
    <!-- Every doc to be index needs an index command before it: -->
    <xsl:text expand-text="false">{"index":{"_id":"</xsl:text>
    <xsl:value-of select="generate-id(.)"/>
    <xsl:text>"}}</xsl:text>
    <xsl:text>&#x0a;</xsl:text>
    
    <xsl:sequence select="fn:xml-to-json($jsonXml)"/>
    <xsl:text>&#x0a;</xsl:text>
    <xsl:apply-templates select="*"/>
  </xsl:template>

  <xsl:template match="@class" mode="ditaClass">
    <fn:array key="ditaclass">
      <xsl:for-each select="tail(tokenize(., ' ')[fn:position() lt last()])">
        <fn:string>{.}</fn:string>
      </xsl:for-each>
    </fn:array>
  </xsl:template>

  <xsl:template match="@*">
    <fn:string key="{name(.)}">{.}</fn:string>
  </xsl:template>

  <xsl:template match="node() | text()" priority="-1" mode="#all">
    <xsl:apply-templates mode="#current"/>
  </xsl:template>

  <xsl:function name="local:getNodeId" as="xs:string">
    <xsl:param name="context" as="node()"/>

    <xsl:variable name="topicParent" as="element()?"
      select="$context/ancestor-or-self::*[contains-token(@class, 'topic/topic')][1]"/>
    <xsl:variable name="baseId" as="xs:string" select="($context/@id, generate-id($context))[1]"/>
    <xsl:variable name="result" as="xs:string" select="
        if ($context is $topicParent)
        then
          $context/@id
        else
          if (exists($topicParent))
          then
            ($topicParent/@id || '^' || $baseId)
          else
            $baseId
        "/>
    <xsl:sequence select="$result"/>
  </xsl:function>

</xsl:stylesheet>
