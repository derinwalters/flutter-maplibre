package com.github.josxha.maplibre

import androidx.annotation.Keep
import okhttp3.Cookie
import okhttp3.CookieJar
import okhttp3.Dispatcher
import okhttp3.HttpUrl
import okhttp3.OkHttpClient
import org.maplibre.android.module.http.HttpRequestUtil

/**
 * The cookies MapLibre's own requests carry, live maps and offline downloads
 * alike: every one goes through the OkHttp client [HttpRequestUtil] holds.
 *
 * The first [set] gives MapLibre a client like its default one (a dispatcher
 * allowing 20 requests per host) with this jar, which answers only for the
 * cookies set here and never stores one from a response. MapLibre must be
 * initialized first (`MapLibre.getInstance`): its request class reads the app
 * context when it loads.
 */
@Keep
object NetworkCookies : CookieJar {
    @Volatile
    private var cookies: List<Cookie> = emptyList()

    private var installed = false

    /**
     * Sets the cookie [name]=[value] on every request MapLibre makes over
     * https to [host] alone for a path under [path], until [expiresAt]
     * (milliseconds since the epoch); one whose [expiresAt] has passed
     * removes it. A later call with the same host, path and name replaces it
     * from the next request on.
     */
    @JvmStatic
    fun set(host: String, path: String, name: String, value: String, expiresAt: Long) {
        synchronized(this) {
            if (!installed) {
                HttpRequestUtil.setOkHttpClient(
                    OkHttpClient.Builder()
                        .dispatcher(Dispatcher().apply { maxRequestsPerHost = 20 })
                        .cookieJar(this)
                        .build(),
                )
                installed = true
            }
            val cookie = Cookie.Builder()
                .name(name)
                .value(value)
                .hostOnlyDomain(host)
                .path(path)
                .secure()
                .expiresAt(expiresAt)
                .build()
            val others = cookies.filterNot {
                it.name == cookie.name && it.domain == cookie.domain && it.path == cookie.path
            }
            cookies = if (expiresAt > System.currentTimeMillis()) others + cookie else others
        }
    }

    override fun loadForRequest(url: HttpUrl): List<Cookie> {
        val now = System.currentTimeMillis()
        return cookies.filter { it.expiresAt > now && it.matches(url) }
    }

    override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) = Unit
}
