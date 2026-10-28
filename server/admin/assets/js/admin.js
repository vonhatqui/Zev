/**
 * ZEV Admin Panel — JavaScript Utilities
 */

// ─── Toast Notifications ──────────────────────────────────────
function showToast(message, type = 'success', duration = 3500) {
  const container = document.getElementById('toastContainer');
  if (!container) return;

  const icons = { success: '✅', error: '❌', warning: '⚠️', info: 'ℹ️' };
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.innerHTML = `<span>${icons[type] || '📢'}</span><span>${message}</span>`;
  container.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateX(24px)';
    toast.style.transition = '0.3s ease';
    setTimeout(() => toast.remove(), 300);
  }, duration);
}

// ─── Modal Control ────────────────────────────────────────────
function openModal(id) {
  const overlay = document.getElementById(id);
  if (overlay) overlay.classList.add('active');
}

function closeModal(id) {
  const overlay = document.getElementById(id);
  if (overlay) overlay.classList.remove('active');
}

// Close on backdrop click
document.addEventListener('click', function(e) {
  if (e.target.classList.contains('modal-overlay')) {
    e.target.classList.remove('active');
  }
});

// Close on Escape
document.addEventListener('keydown', function(e) {
  if (e.key === 'Escape') {
    document.querySelectorAll('.modal-overlay.active').forEach(m => m.classList.remove('active'));
  }
});

// ─── Clipboard ────────────────────────────────────────────────
async function copyText(text) {
  try {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      await navigator.clipboard.writeText(text);
    } else {
      // Fallback
      const el = document.createElement('textarea');
      el.value = text;
      el.style.position = 'fixed';
      el.style.opacity = '0';
      document.body.appendChild(el);
      el.select();
      document.execCommand('copy');
      document.body.removeChild(el);
    }
    showToast('Đã sao chép!', 'success', 1500);
  } catch {
    showToast('Không thể sao chép', 'error');
  }
}

// ─── Confirm Delete ────────────────────────────────────────────
function confirmDelete(message, callback) {
  if (confirm(message)) callback();
}

// ─── Search Debounce ──────────────────────────────────────────
(function() {
  const search = document.getElementById('searchInput');
  if (!search) return;

  let timer;
  search.addEventListener('input', function() {
    clearTimeout(timer);
    timer = setTimeout(() => {
      const form = this.closest('form');
      if (form) form.submit();
    }, 600);
  });
})();

// ─── File Upload Progress ──────────────────────────────────────
function initFileUpload(inputId, progressId, maxMb = 100) {
  const input    = document.getElementById(inputId);
  const progress = document.getElementById(progressId);
  if (!input || !progress) return;

  input.addEventListener('change', function() {
    const file = this.files[0];
    if (!file) return;

    const sizeMb = file.size / 1024 / 1024;
    if (sizeMb > maxMb) {
      showToast(`File quá lớn (${sizeMb.toFixed(1)} MB > ${maxMb} MB)`, 'error');
      this.value = '';
      return;
    }

    // Display size info
    const infoEl = document.getElementById(inputId + '_info');
    if (infoEl) {
      infoEl.textContent = `${file.name} — ${sizeMb.toFixed(2)} MB`;
    }
  });
}

// ─── Auto-dismiss Alerts ──────────────────────────────────────
(function() {
  document.querySelectorAll('.alert[id]').forEach(function(el) {
    setTimeout(function() {
      el.style.opacity = '0';
      el.style.transition = '0.5s';
      setTimeout(function() { el.style.display = 'none'; }, 500);
    }, 5000);
  });
})();

// ─── Format Bytes ─────────────────────────────────────────────
function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return (bytes / Math.pow(k, i)).toFixed(2) + ' ' + sizes[i];
}

// ─── Table Row Click ──────────────────────────────────────────
document.querySelectorAll('tr[data-href]').forEach(function(row) {
  row.style.cursor = 'pointer';
  row.addEventListener('click', function(e) {
    if (!e.target.closest('button') && !e.target.closest('a')) {
      window.location.href = this.dataset.href;
    }
  });
});

console.log('%c🔑 Zev Admin Panel', 'color:#6c63ff; font-size:18px; font-weight:bold;');
console.log('%c Hệ thống quản trị được bảo vệ. Không chia sẻ quyền truy cập.', 'color:#8b91a8;');
