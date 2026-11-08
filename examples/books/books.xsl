<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes" omit-xml-declaration="yes"/>

  <xsl:template match="/">
    <report>
      <count>
        <xsl:value-of select="count(//book)"/>
      </count>
      <total>
        <xsl:value-of select="sum(//price)"/>
      </total>
      <books>
        <xsl:apply-templates select="//book">
          <xsl:sort select="price" data-type="number"/>
        </xsl:apply-templates>
      </books>
    </report>
  </xsl:template>

  <xsl:template match="book">
    <book id="{@id}" year="{@year}">
      <title>
        <xsl:value-of select="title"/>
      </title>
      <author>
        <xsl:value-of select="author"/>
      </author>
      <price>
        <xsl:value-of select="price"/>
      </price>
    </book>
  </xsl:template>
</xsl:stylesheet>