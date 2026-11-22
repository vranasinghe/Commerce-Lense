# Publishing CommerceLens to Power BI Service (shareable link)

The report reads from **local SQL Server** (`.` / `olist_dw`), so the cloud service cannot refresh it without extra setup. Choose one of the three options below.

## Prerequisites
- Work or school Microsoft account with a Power BI license. A **Pro** or Premium Per User license is required to share with others. A free license only lets you publish to "My workspace" for yourself.
- The warehouse built and the report refreshed in Power BI Desktop. Confirm the visuals show correct values first. See `docs/powerbi-guide.md`.

## Step 1: Publish from Power BI Desktop (all options)
1. Open `powerbi/CommerceLens.pbip` in Power BI Desktop. Click **Refresh**.
2. Sign in (top right) with your Microsoft account.
3. Click **Home -> Publish**, choose a workspace, and confirm.
4. Open the link Power BI shows ("Open 'CommerceLens' in Power BI"). This is your report URL.

> If the PBIP format blocks publishing in your Desktop version, use **File -> Save as** to save a `.pbix` and publish that.

## Step 2: Make the data refresh (choose one)

### Option A: Static snapshot (simplest, good for a demo or portfolio)
Skip scheduled refresh. The published report keeps the data from your last Desktop refresh. Re-publish whenever the data changes.

### Option B: On-premises data gateway (keeps SQL Server local)
1. Install the **On-premises data gateway (standard mode)** on the machine that can reach SQL Server: <https://learn.microsoft.com/data-integration/gateway/service-gateway-install>
2. In Power BI Service: **Settings -> Manage connections and gateways** and confirm the gateway shows as online.
3. Open the dataset's **Settings -> Gateway and cloud connections** and map the SQL Server data source to the gateway.
4. Set the authentication method to **Windows** and enter your Windows credentials. **Do this yourself in the browser. Never share or paste the password into a chat.**
5. Under **Scheduled refresh**, turn it on and pick the times.

### Option C: Move the warehouse to Azure SQL (fully cloud)
1. Create an Azure SQL Database and restore or recreate `olist_dw`. Run the SQL scripts in order, as `run_sql.py` does.
2. In Power BI Desktop, change the data source (**Transform data -> Data source settings**) to the Azure SQL server.
3. Re-publish. No gateway is needed. Set the credentials in the dataset settings.
4. Set `OLIST_ODBC_CONNECTION` for the Python loaders, since Windows authentication will not work against Azure SQL.

## Step 3: Share the link
- **With specific people (needs Pro):** open the report, **Share**, enter their emails. Recipients need a license as well, unless the workspace is on Premium or Fabric capacity.
- **Public "Publish to web" (anyone with the link):** **File -> Embed report -> Publish to web (public)**. This makes the data **public to anyone on the internet**. The Olist dataset is public, but your tenant admin may disable this option. Only use it for non-sensitive data.
- **Portfolio or LinkedIn:** use Publish to web, or put the video link next to a screenshot of each page.

## Troubleshooting
| Symptom | Fix |
|---|---|
| "Can't refresh, data source is local" | Use Option B (gateway) or C (Azure SQL). |
| Gateway offline | Restart the gateway service and make sure the PC is on and online. |
| Credentials error on refresh | Re-enter the Windows credentials in the dataset settings. |
| Publish to web is greyed out | Your admin disabled it. Use Share instead. |
| Visuals show old numbers | Click Refresh in Desktop and re-publish. |
