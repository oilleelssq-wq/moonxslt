<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes" omit-xml-declaration="yes"/>
  <xsl:key name="by-region" match="sale" use="@region"/>

  <xsl:template match="/">
    <report>
      <xsl:for-each select="//sale[not(@region = preceding-sibling::sale/@region)]">
        <region name="{@region}">
          <count><xsl:value-of select="count(key('by-region', @region))"/></count>
          <total>
            <xsl:value-of select="format-number(sum(key('by-region', @region)/@amount), '#,##0.00')"/>
          </total>
        </region>
      </xsl:for-each>
      <grand-total>
        <xsl:value-of select="format-number(sum(//sale/@amount), '#,##0.00')"/>
      </grand-total>
    </report>
  </xsl:template>
</xsl:stylesheet>