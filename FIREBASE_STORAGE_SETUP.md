# 🔥 Firebase Storage Rules Configuration

## 📋 Langkah-langkah untuk memperbaiki Firebase Storage Rules:

### 1. **Buka Firebase Console**

- Pergi ke https://console.firebase.google.com
- Pilih project QuizMateApp

### 2. **Navigasi ke Storage**

- Klik "Storage" di sidebar kiri
- Pilih tab "Rules"

### 3. **Update Rules untuk Development**

Ganti rules yang ada dengan:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Allow all authenticated users to read/write
    match /{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### 4. **Klik "Publish"**

- Klik tombol "Publish" untuk menyimpan rules

### 5. **Verify Rules Applied**

- Pastikan rules sudah ter-apply dengan status "Published"

## ⚠️ PENTING:

Rules di atas sangat permissive dan hanya untuk **DEVELOPMENT**.
Untuk production, gunakan rules yang lebih ketat di file `firebase_storage_rules.txt`.

## 🔄 Setelah Update Rules:

1. Restart aplikasi Flutter
2. Login sebagai Teacher
3. Coba upload file lagi
4. Check logs untuk memastikan tidak ada error 404 lagi

## 🐛 Debug Info:

- Error sebelumnya: `[firebase_storage/object-not-found] No object exists at the desired reference`
- Penyebab: Rules terlalu ketat, tidak mengizinkan write untuk authenticated users
- Solusi: Update rules untuk mengizinkan read/write bagi authenticated users
