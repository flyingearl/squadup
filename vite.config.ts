import inertia from '@inertiajs/vite';
import { wayfinder } from '@laravel/vite-plugin-wayfinder';
import tailwindcss from '@tailwindcss/vite';
import vue from '@vitejs/plugin-vue';
import laravel from 'laravel-vite-plugin';
import { defineConfig } from 'vite';

// The Wayfinder plugin shells out to `php artisan wayfinder:generate` during
// buildStart. That works when Vite runs on the host alongside PHP, but our
// Vite container is pure Node — no PHP binary. When SKIP_WAYFINDER_AUTO is
// set (see docker-compose.override.yml), we skip the plugin and rely on the
// app container's entrypoint to keep the generated files fresh instead.
const plugins = [
    laravel({
        input: ['resources/css/app.css', 'resources/js/app.ts'],
        refresh: true,
    }),
    inertia(),
    tailwindcss(),
    vue({
        template: {
            transformAssetUrls: {
                base: null,
                includeAbsolute: false,
            },
        },
    }),
];

if (!process.env.SKIP_WAYFINDER_AUTO) {
    plugins.push(
        wayfinder({
            formVariants: true,
        }),
    );
}

export default defineConfig({
    plugins,
    // Dev server runs inside the `vite` container (see docker-compose.override.yml).
    // - host 0.0.0.0 makes it reachable through the Docker port map.
    // - origin 'http://localhost:5173' is what gets written into `public/hot`,
    //   which Laravel's @vite directive uses for asset URLs the browser fetches.
    // - hmr.host 'localhost' is where the browser opens its HMR websocket.
    // - watch.usePolling — bind-mounted volumes sometimes miss inotify events.
    server: {
        host: '0.0.0.0',
        port: 5173,
        strictPort: true,
        origin: 'http://localhost:5173',
        hmr: {
            host: 'localhost',
        },
        watch: {
            usePolling: true,
        },
    },
});
