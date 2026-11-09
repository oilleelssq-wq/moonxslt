<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:include href="examples/include/shared.xsl"/>
  <xsl:output method="html" omit-xml-declaration="yes"/>

  <xsl:template match="/">
    <html>
      <body>
        <h1>Price list</h1>
        <ul>
          <xsl:apply-templates select="//item"/>
        </ul>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>