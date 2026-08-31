package pk.pakpocket.pakpocket

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import java.text.NumberFormat
import java.util.Locale

private const val PREFS = "mera_markaz_widgets"

abstract class BaseMeraMarkazWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { update(context, manager, it) }
    }
    abstract fun update(context: Context, manager: AppWidgetManager, id: Int)

    protected fun card(context: Context, title: String, value: String, subtitle: String, route: String): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_card)
        views.setTextViewText(R.id.widget_title, title)
        views.setTextViewText(R.id.widget_value, value)
        views.setTextViewText(R.id.widget_subtitle, subtitle)
        views.setOnClickPendingIntent(R.id.widget_root, launch(context, route, route.hashCode()))
        applyTheme(context, views, R.id.widget_root)
        return views
    }

    protected fun launch(context: Context, route: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("meramarkaz://app$route")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(context, requestCode, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    protected fun hidden(context: Context) = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        .getString("privacy", "hidden") != "visible"

    protected fun money(value: Float, hidden: Boolean): String = if (hidden) "Rs. ••••••" else
        "Rs. ${NumberFormat.getNumberInstance(Locale("en", "PK")).format(value)}"

    protected fun applyTheme(context: Context, views: RemoteViews, root: Int) {
        val pref = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("theme", "system")
        val systemDark = context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK == Configuration.UI_MODE_NIGHT_YES
        val dark = pref == "dark" || (pref == "system" && systemDark)
        views.setInt(root, "setBackgroundColor", if (dark) Color.rgb(16, 20, 28) else Color.rgb(250, 247, 241))
        val foreground = if (dark) Color.WHITE else Color.rgb(25, 28, 35)
        views.setTextColor(R.id.widget_title, foreground)
        views.setTextColor(R.id.widget_value, foreground)
        views.setTextColor(R.id.widget_subtitle, if (dark) Color.LTGRAY else Color.DKGRAY)
    }
}

class MoneySnapshotWidget : BaseMeraMarkazWidget() {
    override fun update(context: Context, manager: AppWidgetManager, id: Int) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val private = hidden(context)
        val income = money(prefs.getFloat("income", 0f), private)
        val expenses = money(prefs.getFloat("expenses", 0f), private)
        val remaining = money(prefs.getFloat("remaining", 0f), private)
        manager.updateAppWidget(id, card(context, "Money Snapshot", remaining, "Income $income  •  Expenses $expenses", "/"))
    }
}

class FinancialInsightWidget : BaseMeraMarkazWidget() {
    override fun update(context: Context, manager: AppWidgetManager, id: Int) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val private = hidden(context)
        val type = prefs.getString("insight", "safe_to_spend")
        val content = when (type) {
            "budget" -> Triple("Budget", "${prefs.getFloat("budgetPercent", 0f).toInt()}%", "Tap to review spending")
            "udhaar" -> Triple("Udhaar", money(prefs.getFloat("receivable", 0f), private), "To receive • Tap for ledger")
            "savings" -> Triple(prefs.getString("savingsGoal", "Savings goal") ?: "Savings goal", "${(prefs.getFloat("savingsProgress", 0f) * 100).toInt()}%", "Tap to add savings")
            "upcoming" -> Triple("Upcoming", money(prefs.getFloat("upcoming", 0f), private), "Essential payments this month")
            "fuel" -> Triple("Fuel", money(prefs.getFloat("fuelMonthly", 0f), private), "Monthly fuel expense")
            "net_worth" -> Triple("Net Worth", money(prefs.getFloat("netWorth", 0f), private), "Private snapshot")
            "health" -> Triple("Financial Health", "${prefs.getFloat("healthScore", 0f).toInt()} / 100", "Explainable local score")
            "solar" -> Triple("Solar ROI", "${(prefs.getFloat("solarProgress", 0f) * 100).toInt()}%", "Payback progress")
            "zakat" -> Triple("Zakat Review", prefs.getString("zakatReview", "Not scheduled") ?: "Not scheduled", "No Zakat amount shown")
            else -> Triple("Safe to Spend", money(prefs.getFloat("safeToSpend", 0f), private), "After upcoming payments and reserve")
        }
        val route = when (type) { "udhaar" -> "/udhaar"; "savings" -> "/savings"; "fuel" -> "/vehicles"; "solar" -> "/energy-intelligence"; "zakat" -> "/gold-zakat"; "net_worth" -> "/advanced"; else -> "/" }
        manager.updateAppWidget(id, card(context, content.first, content.second, content.third, route))
    }
}

class PakistanLiveWidget : BaseMeraMarkazWidget() {
    override fun update(context: Context, manager: AppWidgetManager, id: Int) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val key = prefs.getString("market", "usd_pkr") ?: "usd_pkr"
        val raw = prefs.getString("market_$key", null)?.split("|")
        val title = mapOf("usd_pkr" to "USD/PKR", "aed_pkr" to "AED/PKR", "sar_pkr" to "SAR/PKR", "gold_24k_tola" to "Gold 24K / Tola", "petrol" to "Petrol")[key] ?: key
        val value = raw?.getOrNull(0) ?: "Unavailable"
        val subtitle = if (raw == null) "Open Mera Markaz to refresh" else "${raw.getOrNull(1) ?: "Saved source"} • ${raw.getOrNull(2) ?: "cached"}"
        manager.updateAppWidget(id, card(context, title, value, subtitle, "/pakistan-live"))
    }
}

class QuickActionsWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_quick_actions)
            val selected = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString("quickActions", "expense,udhaar,savings")!!.split(",").take(3)
            val slots = listOf(R.id.quick_expense, R.id.quick_udhaar, R.id.quick_savings)
            slots.forEachIndexed { index, viewId ->
                val action = selected.getOrNull(index) ?: "expense"
                val option = when (action) {
                    "income" -> "+ Income" to "/expenses"
                    "udhaar" -> "+ Udhaar" to "/udhaar"
                    "fuel" -> "+ Fuel" to "/vehicles"
                    "scan" -> "Scan" to "/advanced"
                    "savings" -> "+ Saving" to "/savings"
                    else -> "+ Expense" to "/expenses"
                }
                views.setTextViewText(viewId, option.first)
                views.setOnClickPendingIntent(viewId, launch(context, option.second, 1001 + index))
            }
            manager.updateAppWidget(id, views)
        }
    }
    private fun launch(context: Context, route: String, code: Int) = PendingIntent.getActivity(
        context, code, Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("meramarkaz://app$route")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}

object MeraMarkazWidgets {
    fun updateAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        listOf(
            MoneySnapshotWidget::class.java,
            FinancialInsightWidget::class.java,
            PakistanLiveWidget::class.java,
            QuickActionsWidget::class.java,
        ).forEach { provider ->
            val component = ComponentName(context, provider)
            manager.notifyAppWidgetViewDataChanged(manager.getAppWidgetIds(component), R.id.widget_root)
            context.sendBroadcast(Intent(context, provider).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, manager.getAppWidgetIds(component))
            })
        }
    }
}
