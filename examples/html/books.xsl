<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html"/>

  <xsl:template match="/">
    <html>
      <head>
        <title>Book catalogue</title>
      </head>
      <body>
        <h1>Book catalogue</h1>
        <table border="1">
          <tr>
            <th>Title</th>
            <th>Author</th>
            <th>Price</th>
          </tr>
          <xsl:for-each select="//book">
            <tr>
              <td>
                <xsl:value-of select="title"/>
              </td>
              <td>
                <xsl:value-of select="author"/>
              </td>
              <td>
                <xsl:value-of select="price"/>
              </td>
            </tr>
          </xsl:for-each>
        </table>
        <hr/>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>