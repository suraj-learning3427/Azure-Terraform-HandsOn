// ── Tab switching ────────────────────────────────────────────────────────────
document.querySelectorAll('.tab-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    const group = btn.closest('.tabs').dataset.group;
    document.querySelectorAll(`.tab-btn[data-group="${group}"], .tab-panel[data-group="${group}"]`)
      .forEach(el => el.classList.remove('active'));
    btn.classList.add('active');
    document.querySelector(`.tab-panel[data-group="${group}"][data-tab="${btn.dataset.tab}"]`)
      ?.classList.add('active');
  });
});

// ── Q&A accordion ────────────────────────────────────────────────────────────
document.querySelectorAll('.qa-question').forEach(btn => {
  btn.addEventListener('click', () => {
    const answer = btn.nextElementSibling;
    const isOpen = btn.classList.contains('open');
    // Close all in same list
    btn.closest('.qa-list')?.querySelectorAll('.qa-question, .qa-answer')
      .forEach(el => el.classList.remove('open'));
    if (!isOpen) {
      btn.classList.add('open');
      answer.classList.add('open');
    }
  });
});

// ── Copy code buttons ─────────────────────────────────────────────────────────
document.querySelectorAll('.copy-btn').forEach(btn => {
  btn.addEventListener('click', () => {
    const code = btn.closest('.code-block').querySelector('pre').innerText;
    navigator.clipboard.writeText(code).then(() => {
      btn.textContent = '✓ Copied';
      btn.classList.add('copied');
      setTimeout(() => { btn.textContent = 'Copy'; btn.classList.remove('copied'); }, 2000);
    });
  });
});

// ── Active nav link ───────────────────────────────────────────────────────────
const current = location.pathname.split('/').pop() || 'index.html';
document.querySelectorAll('.nav-link').forEach(link => {
  if (link.getAttribute('href') === current) link.classList.add('active');
  else link.classList.remove('active');
});
