<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:template match="item">
    <li>
      <xsl:value-of select="name"/>
      <xsl:text> (</xsl:text>
      <xsl:value-of select="format-number(@price, '#,##0.00')"/>
      <xsl:text>)</xsl:text>
    </li>
  </xsl:template>
</xsl:stylesheet>