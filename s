<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <title>Akıllı Kitaplığım v9 - Net Odak</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/quagga/0.12.1/quagga.min.js"></script>
    <style>
        :root { --wood: #3e2723; --shelf-shadow: #1b110f; --accent: #ffb74d; --bg: #121212; }
        body { font-family: 'Segoe UI', sans-serif; background: var(--bg); margin: 0; color: white; }
        
        .admin-panel {
            background: #1f1f1f; padding: 10px; display: flex; flex-wrap: wrap; gap: 8px;
            position: sticky; top: 0; z-index: 1000; box-shadow: 0 4px 10px rgba(0,0,0,0.5);
        }

        .input-box { flex: 1; padding: 12px; border-radius: 8px; border: none; background: #333; color: white; }
        .btn-ui { padding: 12px 18px; border-radius: 8px; border: none; font-weight: bold; cursor: pointer; }
        .add-btn { background: var(--accent); color: #000; }
        .scan-btn { background: #0288d1; color: white; }

        /* Tarayıcı Alanı */
        #scanner-container {
            display: none; width: 100%; height: 350px; background: black;
            position: relative; overflow: hidden; border-bottom: 3px solid var(--accent);
        }
        #scanner-container video { width: 100%; height: 100%; object-fit: cover; }
        
        /* Odaklama Çerçevesi */
        .focus-guide {
            position: absolute; top: 50%; left: 50%;
            transform: translate(-50%, -50%);
            width: 70%; height: 40%;
            border: 2px dashed rgba(255, 255, 255, 0.5);
            border-radius: 10px; pointer-events: none; z-index: 15;
        }
        .scanner-laser {
            position: absolute; top: 50%; left: 15%; width: 70%; height: 2px;
            background: red; box-shadow: 0 0 10px red; z-index: 10;
            animation: scanAnim 2s infinite;
        }
        @keyframes scanAnim { 0%, 100% { top: 30%; } 50% { top: 70%; } }

        /* Kitaplık Yapısı */
        .library { padding: 20px 10px 100px 10px; display: flex; flex-direction: column; gap: 40px; }
        .shelf {
            background: var(--wood); border-bottom: 15px solid var(--shelf-shadow);
            min-height: 115px; display: flex; align-items: flex-end; padding: 0 10px; flex-wrap: wrap;
        }
        .book {
            width: 44px; height: 100px; margin: 0 3px 2px 3px; cursor: pointer;
            display: flex; align-items: center; justify-content: center;
            font-size: 10px; font-weight: bold; color: white; text-align: center;
            writing-mode: vertical-rl; border-radius: 2px 4px 4px 2px;
            box-shadow: 3px 0 5px rgba(0,0,0,0.6); background-color: #5d4037;
            background-size: cover; border-left: 3px solid rgba(255,255,255,0.2);
            position: relative; overflow: hidden;
        }
        .book-title-overlay { background: rgba(0,0,0,0.5); width: 100%; padding: 6px 0; }

        /* Modal */
        .modal {
            display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%;
            background: rgba(0,0,0,0.95); z-index: 2000; justify-content: center; align-items: center;
        }
        .modal-content {
            background: #252525; width: 90%; max-width: 450px; border-radius: 15px; padding: 20px;
            box-sizing: border-box; border: 1px solid #444;
        }
        label { color: var(--accent); font-size: 13px; display: block; margin-top: 10px; }
        .edit-input, textarea { width: 100%; background: #333; border: 1px solid #444; color: white; padding: 10px; border-radius: 8px; margin-top: 5px; box-sizing: border-box; }
        .modal-btns { display: flex; gap: 10px; margin-top: 20px; }
    </style>
</head>
<body>

<div class="admin-panel">
    <input type="text" id="bookTitleInput" class="input-box" placeholder="Kitap Adı...">
    <button class="btn-ui add-btn" onclick="addNewBook()">EKLE</button>
    <button class="btn-ui scan-btn" onclick="toggleScanner()">BARKOD OKUT</button>
</div>

<div id="scanner-container">
    <div class="focus-guide"></div>
    <div class="scanner-laser"></div>
</div>

<div class="library" id="library">
    <div class="shelf"></div>
    <div class="shelf"></div>
</div>

<div id="bookModal" class="modal">
    <div class="modal-content">
        <h3 style="text-align:center;">Kitap Düzenle</h3>
        <label>Kitap İsmi:</label>
        <input type="text" id="mEditTitle" class="edit-input">
        <label>Notlar:</label>
        <textarea id="mNotes" rows="3"></textarea>
        <div class="modal-btns">
            <button class="btn-ui" style="background:#c62828; color:white; flex:1;" onclick="deleteBook()">Sil</button>
            <button class="btn-ui" style="background:#2e7d32; color:white; flex:1;" onclick="saveDetails()">Kaydet</button>
        </div>
    </div>
</div>

<script>
    let editingBook = null;

    // LOCAL STORAGE YÜKLEME
    window.onload = () => {
        const saved = JSON.parse(localStorage.getItem('myLibrary_v9') || '[]');
        saved.forEach(data => createBookElement(data));
    };

    function saveLibrary() {
        const books = document.querySelectorAll('.book');
        const data = Array.from(books).map(b => JSON.parse(b.dataset.info));
        localStorage.setItem('myLibrary_v9', JSON.stringify(data));
    }

    // BARKOD SİSTEMİ
    function toggleScanner() {
        const container = document.getElementById('scanner-container');
        if (container.style.display === 'block') {
            Quagga.stop();
            container.style.display = 'none';
        } else {
            container.style.display = 'block';
            startScanner();
        }
    }

    function startScanner() {
        Quagga.init({
            inputStream: {
                name: "Live",
                type: "LiveStream",
                target: document.querySelector('#scanner-container'),
                constraints: {
                    facingMode: "environment",
                    focusMode: "continuous", // SÜREKLİ ODAKLAMA MODU
                    width: { ideal: 1280 }, // Daha yüksek çözünürlük netlik sağlar
                    height: { ideal: 720 }
                },
            },
            locator: { patchSize: "medium", halfSample: false }, // halfSample false daha net ama yavaş işler
            decoder: { readers: ["ean_reader"] }, // Kitaplar için sadece EAN yeterli
            locate: true
        }, function(err) {
            if (err) return alert("Hata: " + err);
            
            // Kamera açıldıktan sonra ekstra odaklama desteği denemesi
            const track = Quagga.CameraAccess.getActiveTrack();
            if (track && typeof track.getCapabilities === 'function') {
                const caps = track.getCapabilities();
                if (caps.focusMode && caps.focusMode.includes('continuous')) {
                    track.applyConstraints({ advanced: [{ focusMode: 'continuous' }] });
                }
            }
            Quagga.start();
        });

        Quagga.onDetected((result) => {
            const code = result.codeResult.code;
            if (code) {
                Quagga.stop();
                document.getElementById('scanner-container').style.display = 'none';
                if (navigator.vibrate) navigator.vibrate(200);
                fetchBook(code);
            }
        });
    }

    async function fetchBook(isbn) {
        try {
            const res = await fetch(`https://www.googleapis.com/books/v1/volumes?q=isbn:${isbn}`);
            const data = await res.json();
            if (data.items) {
                addNewBook(data.items[0].volumeInfo.title);
            } else {
                alert("Barkod: " + isbn + " bulundu ama kitap ismi alınamadı.");
            }
        } catch (e) { alert("Bağlantı hatası."); }
    }

    function addNewBook(title) {
        const t = title || document.getElementById('bookTitleInput').value;
        if (!t) return;
        createBookElement({ title: t, notes: '', color: '#5d4037' });
        document.getElementById('bookTitleInput').value = '';
        saveLibrary();
    }

    function createBookElement(data) {
        const book = document.createElement('div');
        book.className = 'book';
        book.style.backgroundColor = data.color;
        book.innerHTML = `<div class="book-title-overlay">${data.title}</div>`;
        book.dataset.info = JSON.stringify(data);
        book.onclick = () => openModal(book);
        
        const shelves = document.querySelectorAll('.shelf');
        let target = shelves[0];
        for(let s of shelves) { if(s.children.length < 10) { target = s; break; } }
        target.appendChild(book);
    }

    function openModal(book) {
        editingBook = book;
        const data = JSON.parse(book.dataset.info);
        document.getElementById('mEditTitle').value = data.title;
        document.getElementById('mNotes').value = data.notes;
        document.getElementById('bookModal').style.display = 'flex';
    }

    function saveDetails() {
        const data = JSON.parse(editingBook.dataset.info);
        data.title = document.getElementById('mEditTitle').value;
        data.notes = document.getElementById('mNotes').value;
        editingBook.querySelector('.book-title-overlay').innerText = data.title;
        editingBook.dataset.info = JSON.stringify(data);
        saveLibrary();
        document.getElementById('bookModal').style.display = 'none';
    }

    function deleteBook() {
        editingBook.remove();
        saveLibrary();
        document.getElementById('bookModal').style.display = 'none';
    }

    window.onclick = (e) => { if(e.target.className === 'modal') document.getElementById('bookModal').style.display = 'none'; }
</script>
</body>
</html>
