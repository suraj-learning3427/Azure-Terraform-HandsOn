// Inject sidebar into every page
const NAV_HTML = `
<nav class="sidebar">
  <div class="sidebar-header">
    <div class="logo">⚡ Azure Training</div>
    <div class="subtitle">Apr 7–30, 2026</div>
  </div>
  <ul class="nav-list">
    <li><a href="index.html" class="nav-link">🏠 Overview</a></li>
    <li class="nav-section">Week 1</li>
    <li><a href="day-01.html" class="nav-link">Day 1 — App Service + Terraform</a></li>
    <li><a href="day-02.html" class="nav-link">Day 2 — SQL + Containers</a></li>
    <li><a href="day-03.html" class="nav-link">Day 3 — Auth + APIM</a></li>
    <li class="nav-section">Week 2</li>
    <li><a href="day-04.html" class="nav-link">Day 4 — DevOps + Modules</a></li>
    <li><a href="day-05.html" class="nav-link">Day 5 — CI/CD + AKS</a></li>
    <li><a href="day-06.html" class="nav-link">Day 6 — GitHub Actions</a></li>
    <li class="nav-section">Week 3</li>
    <li><a href="day-07.html" class="nav-link">Day 7 — Release Strategies</a></li>
    <li><a href="day-08.html" class="nav-link">Day 8 — Canary + A/B Testing</a></li>
    <li><a href="day-09.html" class="nav-link">Day 9 — Security</a></li>
    <li class="nav-section">Week 4</li>
    <li><a href="day-10.html" class="nav-link">Day 10 — Full Pipeline POC</a></li>
    <li><a href="day-11.html" class="nav-link">Day 11 — 3-Tier + GitOps</a></li>
    <li><a href="day-12.html" class="nav-link">Day 12 — Interview Prep</a></li>
  </ul>
</nav>`;

document.body.insertAdjacentHTML('afterbegin', NAV_HTML);
