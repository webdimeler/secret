# Secret KFS — Android Store

Flutter customer app connected to the existing Secret KFS Supabase project.

## Features
- Arabic RTL storefront, product search and category filters.
- Live products, images, prices, featured products, sizes, colors and stock.
- Shopping cart and quantity controls.
- Checkout through the existing `create-customer-order` Edge Function.
- Order confirmation and order number.
- WhatsApp, map and email links from store settings.

## Build APK
Open GitHub Actions and run **Build Secret KFS Android APK**, or push changes under `android_store/` on branch `android-store-app`. The workflow generates Android project files, builds a release APK, and uploads it as an artifact.

No service-role key is stored in the app. Order prices and stock are validated server-side by the existing Edge Function.

## First version
Cart contents are saved locally on the device and restored when the app is reopened. The website uses guest checkout, so this app does not add customer accounts. Admin product/order management remains in the existing web dashboard.
