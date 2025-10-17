import { defineConfig } from 'vite';
import { createHtmlPlugin } from 'vite-plugin-html'

export default defineConfig({
    base: './',
    build: {
        outDir: '../module/webroot',
    },
    plugins: [
        createHtmlPlugin({
            minify: true
        })
    ]
});
