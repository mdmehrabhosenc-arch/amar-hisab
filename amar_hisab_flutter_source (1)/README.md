# আমার হিসাব — Flutter source

এটি একটি প্রাথমিক Flutter অ্যাপের সোর্স কোড। এতে বাংলা UI, আয়/ব্যয় যোগ, বিবরণ, তারিখ, লেনদেন সম্পাদনা/মুছে ফেলা, ফোনে SQLite সংরক্ষণ এবং মাসিক আয়-ব্যয়ের চার্ট আছে।

## APK তৈরি (GitHub Actions)
1. GitHub-এ একটি নতুন repository তৈরি করুন।
2. এই ZIP-এর ফাইলগুলো repository-তে আপলোড করে commit করুন।
3. Actions ট্যাবে `Build Amar Hisab APK` workflow চালু করুন।
4. সফল হলে workflow run খুলে Artifacts থেকে `amar-hisab-apk` ডাউনলোড করুন।
5. ZIP extract করলে `app-release.apk` পাবেন।

GitHub-এর ফ্রি সীমা ও account/repository settings প্রযোজ্য। APK সরাসরি Android ফোনে ইনস্টল করা যায়; অজানা উৎস থেকে ইনস্টল করার অনুমতি লাগতে পারে।

## গুরুত্বপূর্ণ
- এটি প্রাথমিক সংস্করণ; APK তৈরি হওয়ার পর বাস্তব ফোনে পরীক্ষা করুন।
- অ্যাপের ডেটা শুধু ওই ফোনে SQLite-এ থাকে। অ্যাপ uninstall করলে বা ফোন হারালে ডেটা হারাতে পারে। পরবর্তী সংস্করণে export/backup যোগ করা ভালো।
- Google Play-এ প্রকাশ করতে চাইলে আলাদা signing ও Play Console সেটআপ লাগবে।
