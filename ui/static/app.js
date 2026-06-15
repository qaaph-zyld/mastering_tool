(() => {
    const $ = (sel) => document.querySelector(sel);
    const $id = (id) => document.getElementById(id);

    const dropZone = $id('drop-zone');
    const fileInput = $id('file-input');
    const fileInfo = $id('file-info');
    const fileName = $id('file-name');
    const fileStatus = $id('file-status');
    const genreSelect = $id('genre');
    const vocalPrep = $id('vocal-prep');
    const outputName = $id('output-name');
    const runBtn = $id('run-btn');
    const progress = $id('progress');
    const statusText = $id('status-text');
    const logSection = $id('log');
    const logContent = $id('log-content');
    const downloads = $id('downloads');
    const downloadList = $id('download-list');

    let uploadedPath = '';
    let eventSource = null;

    // ---- Load genres ----
    fetch('/api/genres')
        .then(r => r.json())
        .then(genres => {
            genreSelect.innerHTML = '';
            genres.forEach(g => {
                const opt = document.createElement('option');
                opt.value = g.value;
                opt.textContent = g.label;
                genreSelect.appendChild(opt);
            });
        })
        .catch(() => {
            genreSelect.innerHTML = '<option value="">Default</option>';
        });

    // ---- Drag & Drop ----
    ['dragenter', 'dragover'].forEach(evt => {
        dropZone.addEventListener(evt, (e) => {
            e.preventDefault();
            dropZone.classList.add('dragover');
        });
    });
    ['dragleave', 'drop'].forEach(evt => {
        dropZone.addEventListener(evt, (e) => {
            e.preventDefault();
            dropZone.classList.remove('dragover');
        });
    });
    dropZone.addEventListener('drop', (e) => {
        const files = e.dataTransfer.files;
        if (files.length) handleFile(files[0]);
    });
    dropZone.addEventListener('click', () => fileInput.click());
    fileInput.addEventListener('change', () => {
        if (fileInput.files.length) handleFile(fileInput.files[0]);
    });

    function handleFile(file) {
        if (!file.name.toLowerCase().endsWith('.wav')) {
            alert('Only .wav files are supported.');
            return;
        }
        uploadedPath = '';
        fileName.textContent = file.name;
        fileStatus.textContent = 'Uploading...';
        fileInfo.classList.remove('hidden');
        runBtn.disabled = true;

        const form = new FormData();
        form.append('file', file);

        fetch('/api/upload', { method: 'POST', body: form })
            .then(r => r.json())
            .then(data => {
                if (data.ok) {
                    uploadedPath = data.path;
                    fileStatus.textContent = 'Ready';
                    fileStatus.style.color = 'var(--success)';
                    runBtn.disabled = false;
                    // Auto-fill output name from filename (no extension)
                    if (!outputName.value) {
                        const base = file.name.replace(/\.wav$/i, '').replace(/[^A-Za-z0-9_]/g, '_');
                        outputName.value = base.slice(0, 50);
                    }
                } else {
                    throw new Error(data.error || 'Upload failed');
                }
            })
            .catch(err => {
                fileStatus.textContent = 'Error';
                fileStatus.style.color = 'var(--error)';
                alert(err.message || 'Upload failed');
            });
    }

    // ---- Run Pipeline ----
    runBtn.addEventListener('click', () => {
        if (!uploadedPath) return;
        startRun();
    });

    function startRun() {
        runBtn.disabled = true;
        progress.classList.remove('hidden');
        logSection.classList.remove('hidden');
        downloads.classList.add('hidden');
        downloadList.innerHTML = '';
        logContent.textContent = '';
        statusText.textContent = 'Running pipeline...';

        const params = new URLSearchParams({
            path: uploadedPath,
            genre: genreSelect.value,
            vocal_prep: vocalPrep.checked ? '1' : '0',
            output_name: outputName.value.trim(),
        });

        eventSource = new EventSource('/api/run?' + params.toString());

        eventSource.onmessage = (e) => {
            appendLog(e.data);
        };

        eventSource.addEventListener('done', (e) => {
            eventSource.close();
            finishRun(JSON.parse(e.data));
        });

        eventSource.onerror = () => {
            eventSource.close();
            statusText.textContent = 'Connection lost';
            runBtn.disabled = false;
        };
    }

    function appendLog(text) {
        const line = document.createElement('div');
        line.textContent = text;
        if (text.startsWith('[ERROR]') || text.includes('ERROR') || text.includes('OVER')) {
            line.className = 'line-error';
        } else if (text.startsWith('============ DONE')) {
            line.className = 'line-done';
        } else if (text.match(/^\[[A-Z]\]/)) {
            line.className = 'line-stage';
        }
        logContent.appendChild(line);
        logSection.scrollTop = logSection.scrollHeight;
    }

    function finishRun(data) {
        progress.classList.add('hidden');
        runBtn.disabled = false;

        if (data.error) {
            statusText.textContent = 'Failed';
            return;
        }

        if (data.files && data.files.length) {
            downloads.classList.remove('hidden');
            downloadList.innerHTML = '';
            data.files.forEach(f => {
                const li = document.createElement('li');
                const a = document.createElement('a');
                a.href = f.url;
                a.download = f.name;
                a.innerHTML = `<span>${escapeHtml(f.name)}</span><span class="file-size">${formatSize(f.size)}</span>`;
                li.appendChild(a);
                downloadList.appendChild(li);
            });
        }
    }

    function escapeHtml(str) {
        const div = document.createElement('div');
        div.textContent = str;
        return div.innerHTML;
    }

    function formatSize(bytes) {
        if (bytes < 1024) return bytes + ' B';
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
        return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
    }
})();
