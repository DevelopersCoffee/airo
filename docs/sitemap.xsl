<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="2.0" 
                xmlns:html="http://www.w3.org/TR/REC-html40"
                xmlns:image="http://www.google.com/schemas/sitemap-image/1.1"
                xmlns:sitemap="http://www.sitemaps.org/schemas/sitemap/0.9"
                xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" version="1.0" encoding="UTF-8" indent="yes"/>
  <xsl:template match="/">
    <html lang="en">
      <head>
        <title>Airo — XML Sitemap &amp; AI Agent Index</title>
        <meta charset="utf-8"/>
        <meta name="viewport" content="width=device-width, initial-scale=1"/>
        <meta name="description" content="SEO and AI-agent optimized sitemap for Airo Super App and Documentation."/>
        <style>
          :root {
            --bg: #0f172a;
            --card-bg: #1e293b;
            --text-primary: #f8fafc;
            --text-secondary: #94a3b8;
            --accent: #38bdf8;
            --accent-glow: rgba(56, 189, 248, 0.15);
            --border: #334155;
            --badge-bg: #0284c7;
            --badge-text: #ffffff;
            --row-hover: #26354a;
          }
          body {
            font-family: system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
            background-color: var(--bg);
            color: var(--text-primary);
            margin: 0;
            padding: 30px 20px;
            line-height: 1.6;
          }
          .container {
            max-width: 1100px;
            margin: 0 auto;
          }
          header {
            background: linear-gradient(135deg, #1e293b 0%, #0f172a 100%);
            border: 1px solid var(--border);
            border-radius: 16px;
            padding: 32px;
            margin-bottom: 24px;
            box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3);
          }
          h1 {
            margin: 0 0 10px 0;
            font-size: 2rem;
            color: var(--accent);
            display: flex;
            align-items: center;
            gap: 12px;
          }
          p.subtitle {
            color: var(--text-secondary);
            margin: 0 0 20px 0;
            font-size: 1rem;
          }
          .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 16px;
            margin-top: 20px;
          }
          .stat-card {
            background: rgba(30, 41, 59, 0.7);
            border: 1px solid var(--border);
            border-radius: 12px;
            padding: 16px;
          }
          .stat-value {
            font-size: 1.8rem;
            font-weight: 700;
            color: var(--accent);
          }
          .stat-label {
            font-size: 0.85rem;
            color: var(--text-secondary);
            text-transform: uppercase;
            letter-spacing: 0.05em;
          }
          .agent-banner {
            background: rgba(56, 189, 248, 0.1);
            border: 1px solid rgba(56, 189, 248, 0.3);
            border-radius: 12px;
            padding: 16px 20px;
            margin-bottom: 24px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            flex-wrap: wrap;
            gap: 12px;
          }
          .agent-banner-text {
            font-size: 0.95rem;
            color: var(--text-primary);
          }
          .agent-badge {
            background: var(--badge-bg);
            color: var(--badge-text);
            padding: 6px 14px;
            border-radius: 20px;
            font-size: 0.85rem;
            font-weight: 600;
            text-decoration: none;
            display: inline-block;
            transition: all 0.2s ease;
          }
          .agent-badge:hover {
            transform: translateY(-1px);
            box-shadow: 0 4px 12px var(--accent-glow);
          }
          .search-bar {
            width: 100%;
            padding: 14px 18px;
            border-radius: 10px;
            border: 1px solid var(--border);
            background: var(--card-bg);
            color: var(--text-primary);
            font-size: 1rem;
            box-sizing: border-box;
            margin-bottom: 20px;
            outline: none;
          }
          .search-bar:focus {
            border-color: var(--accent);
            box-shadow: 0 0 0 3px var(--accent-glow);
          }
          table {
            width: 100%;
            border-collapse: separate;
            border-spacing: 0;
            background: var(--card-bg);
            border-radius: 12px;
            overflow: hidden;
            border: 1px solid var(--border);
          }
          th {
            background: #162032;
            color: var(--text-secondary);
            text-align: left;
            padding: 14px 18px;
            font-size: 0.85rem;
            text-transform: uppercase;
            letter-spacing: 0.05em;
            border-bottom: 1px solid var(--border);
          }
          td {
            padding: 14px 18px;
            border-bottom: 1px solid var(--border);
            font-size: 0.95rem;
          }
          tr:last-child td {
            border-bottom: none;
          }
          tr:hover td {
            background: var(--row-hover);
          }
          a {
            color: var(--accent);
            text-decoration: none;
            word-break: break-all;
          }
          a:hover {
            text-decoration: underline;
          }
          .priority-tag {
            display: inline-block;
            padding: 3px 8px;
            border-radius: 6px;
            font-size: 0.8rem;
            font-weight: 600;
            background: #334155;
            color: #f1f5f9;
          }
          .priority-high {
            background: rgba(16, 185, 129, 0.2);
            color: #34d399;
            border: 1px solid rgba(52, 211, 153, 0.3);
          }
          .priority-medium {
            background: rgba(56, 189, 248, 0.2);
            color: #38bdf8;
            border: 1px solid rgba(56, 189, 248, 0.3);
          }
          footer {
            margin-top: 30px;
            text-align: center;
            color: var(--text-secondary);
            font-size: 0.85rem;
          }
        </style>
        <script><![CDATA[
          function filterUrls() {
            var input = document.getElementById('searchInput');
            var filter = input.value.toLowerCase();
            var table = document.getElementById('sitemapTable');
            var tr = table.getElementsByTagName('tr');

            for (var i = 1; i < tr.length; i++) {
              var td = tr[i].getElementsByTagName('td')[0];
              if (td) {
                var txtValue = td.textContent || td.innerText;
                if (txtValue.toLowerCase().indexOf(filter) > -1) {
                  tr[i].style.display = '';
                } else {
                  tr[i].style.display = 'none';
                }
              }
            }
          }
        ]]></script>
      </head>
      <body>
        <div class="container">
          <header>
            <h1>⚡ Airo Super App — Sitemap &amp; AI Discovery</h1>
            <p class="subtitle">Search Engine (SEO) &amp; AI Agent (LLM) Optimized Index for Airo Platform, TV, Coins, &amp; Documentation.</p>
            
            <div class="stats-grid">
              <div class="stat-card">
                <div class="stat-value"><xsl:value-of select="count(sitemap:urlset/sitemap:url)"/></div>
                <div class="stat-label">Indexed URLs</div>
              </div>
              <div class="stat-card">
                <div class="stat-value"><xsl:value-of select="count(sitemap:urlset/sitemap:url[sitemap:priority &gt;= 0.8])"/></div>
                <div class="stat-label">High Priority Pages</div>
              </div>
              <div class="stat-card">
                <div class="stat-value">AI-Ready</div>
                <div class="stat-label">LLM Context</div>
              </div>
            </div>
          </header>

          <div class="agent-banner">
            <div class="agent-banner-text">
              🤖 <strong>AI Agent / LLM Friendly:</strong> Full codebase, docs index, and architectural context are available for AI Agents in <code>llms.txt</code>.
            </div>
            <a href="https://developerscoffee.github.io/airo/llms.txt" class="agent-badge">View llms.txt</a>
          </div>

          <input type="text" id="searchInput" class="search-bar" onkeyup="filterUrls()" placeholder="🔎 Filter URLs or pages (e.g. tv, coins, guides, legal)..."/>

          <table id="sitemapTable">
            <thead>
              <tr>
                <th style="width: 50%;">URL</th>
                <th style="width: 15%;">Priority</th>
                <th style="width: 15%;">Change Freq</th>
                <th style="width: 20%;">Last Modified</th>
              </tr>
            </thead>
            <tbody>
              <xsl:for-each select="sitemap:urlset/sitemap:url">
                <tr>
                  <td>
                    <a href="{sitemap:loc}" target="_blank">
                      <xsl:value-of select="sitemap:loc"/>
                    </a>
                  </td>
                  <td>
                    <xsl:choose>
                      <xsl:when test="sitemap:priority &gt;= 0.8">
                        <span class="priority-tag priority-high"><xsl:value-of select="sitemap:priority"/></span>
                      </xsl:when>
                      <xsl:otherwise>
                        <span class="priority-tag priority-medium"><xsl:value-of select="sitemap:priority"/></span>
                      </xsl:otherwise>
                    </xsl:choose>
                  </td>
                  <td>
                    <xsl:value-of select="sitemap:changefreq"/>
                  </td>
                  <td>
                    <xsl:value-of select="sitemap:lastmod"/>
                  </td>
                </tr>
              </xsl:for-each>
            </tbody>
          </table>

          <footer>
            Generated for Airo Super App • Search Engines &amp; Autonomous AI Agents Compatible
          </footer>
        </div>
      </body>
    </html>
  </xsl:template>
</xsl:stylesheet>
