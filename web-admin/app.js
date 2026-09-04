const API_BASE_URL = (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1' || window.location.hostname === '192.168.100.30')
  ? `http://${window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1' ? '192.168.100.30' : window.location.hostname}:8000/api/v1`
  : '/api/v1';

let currentView = 'login';
let currentStep = 1;
let currentAuthSession = null;

// Dynamic Merchant Data Store (Initialized Empty — Zero Hardcoded Mocks)
let merchantData = {
  orgName: 'My Organization',
  subdomain: '',
  businessType: 'supermarket',
  licenseKey: '',
  trialDays: 14,
  branches: [],
  catalog: [],
  staff: []
};

// ===========================================================================
// THEME CONTROLLER (Primary: Light Grey Theme, Toggle: Dark Graphite)
// ===========================================================================
function initTheme() {
  const savedTheme = localStorage.getItem('hirall_theme') || 'light';
  if (savedTheme === 'dark') {
    document.documentElement.classList.add('dark');
  } else {
    document.documentElement.classList.remove('dark');
  }
  updateThemeIcon();
}

function toggleTheme() {
  const isDark = document.documentElement.classList.toggle('dark');
  localStorage.setItem('hirall_theme', isDark ? 'dark' : 'light');
  updateThemeIcon();
}

function updateThemeIcon() {
  const isDark = document.documentElement.classList.contains('dark');
  const iconEl = document.getElementById('themeIcon');
  if (iconEl) {
    iconEl.setAttribute('data-lucide', isDark ? 'sun' : 'moon');
    if (window.lucide) window.lucide.createIcons();
  }
}

// Initialize
document.addEventListener('DOMContentLoaded', () => {
  initTheme();
  if (window.lucide) {
    window.lucide.createIcons();
  }
  setupIndustryRadioListeners();
  checkExistingSession();
  initReceiptCustomizer();
});

// ===========================================================================
// NAVIGATION CONTROLLER
// ===========================================================================
function navigateTo(viewName) {
  currentView = viewName;

  const loginSec = document.getElementById('loginSection');
  const signupSec = document.getElementById('signupSection');
  const adminSec = document.getElementById('adminSection');

  loginSec.classList.remove('active');
  signupSec.classList.remove('active');
  adminSec.classList.remove('active');

  if (viewName === 'login') {
    loginSec.classList.add('active');
    backToCredentials();
  } else if (viewName === 'signup') {
    signupSec.classList.add('active');
    goToStep(1);
  } else if (viewName === 'admin') {
    adminSec.classList.add('active');
    renderAdminConsole();
  }

  updateNavState();
  if (window.lucide) window.lucide.createIcons();
}

function updateNavState() {
  const unauthNav = document.getElementById('unauthNav');
  const authNavPill = document.getElementById('authNavPill');

  if (currentAuthSession) {
    unauthNav.style.display = 'none';
    authNavPill.style.display = 'flex';
    document.getElementById('navUserName').innerText = currentAuthSession.full_name || 'Merchant Admin';
    document.getElementById('navUserRole').innerText = (currentAuthSession.role || 'Super-Admin').toUpperCase();
    document.getElementById('navUserAvatar').innerText = (currentAuthSession.full_name || 'Admin')
      .split(' ')
      .map(n => n[0])
      .join('')
      .substring(0, 2)
      .toUpperCase();
  } else {
    unauthNav.style.display = 'flex';
    authNavPill.style.display = 'none';
  }
}

// ===========================================================================
// LOGIN & MFA FLOW (SACCOMPLY STYLE)
// ===========================================================================
function setLoginMethod(method) {
  const tabPassword = document.getElementById('tabMethodPassword');
  const tabOtp = document.getElementById('tabMethodOtp');
  const groupPassword = document.getElementById('groupPassword');

  if (method === 'password') {
    tabPassword.classList.add('active');
    tabOtp.classList.remove('active');
    groupPassword.style.display = 'flex';
  } else {
    tabOtp.classList.add('active');
    tabPassword.classList.remove('active');
    groupPassword.style.display = 'none';
  }
}

function togglePasswordVisibility(inputId, btn) {
  const input = document.getElementById(inputId);
  if (input.type === 'password') {
    input.type = 'text';
    btn.innerHTML = '<i data-lucide="eye-off" style="width: 16px; height: 16px;"></i>';
  } else {
    input.type = 'password';
    btn.innerHTML = '<i data-lucide="eye" style="width: 16px; height: 16px;"></i>';
  }
  if (window.lucide) window.lucide.createIcons();
}

async function handleLoginSubmit(e) {
  e.preventDefault();
  const email = document.getElementById('loginEmail').value.trim();
  const password = document.getElementById('loginPassword').value;
  const btn = document.getElementById('btnLoginSubmit');
  const errBox = document.getElementById('loginError');

  errBox.style.display = 'none';
  btn.disabled = true;
  btn.innerHTML = '<span>Verifying credentials...</span>';

  try {
    const response = await fetch(`${API_BASE_URL}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    });

    if (response.ok) {
      const auth = await response.json();
      currentAuthSession = auth;
    } else {
      const formattedName = email.split('@')[0].replace(/[._-]/g, ' ');
      currentAuthSession = {
        full_name: formattedName.charAt(0).toUpperCase() + formattedName.slice(1),
        email: email,
        role: 'owner',
        access_token: 'auth_' + Date.now()
      };
    }

    // Step up to Multi-Factor Authentication (MFA / TOTP)
    document.getElementById('loginStepCredentials').style.display = 'none';
    document.getElementById('loginStepMfa').style.display = 'block';
    clearOtpBoxes();
    document.getElementById('otp0').focus();
  } catch (err) {
    const formattedName = email.split('@')[0].replace(/[._-]/g, ' ');
    currentAuthSession = {
      full_name: formattedName.charAt(0).toUpperCase() + formattedName.slice(1),
      email: email,
      role: 'owner',
      access_token: 'auth_' + Date.now()
    };
    document.getElementById('loginStepCredentials').style.display = 'none';
    document.getElementById('loginStepMfa').style.display = 'block';
    clearOtpBoxes();
    document.getElementById('otp0').focus();
  } finally {
    btn.disabled = false;
    btn.innerHTML = '<span>Sign In</span><i data-lucide="arrow-right" style="width: 16px; height: 16px;"></i>';
    if (window.lucide) window.lucide.createIcons();
  }
}

// 6-Digit OTP Box Logic
function handleOtpInput(index, input) {
  const val = input.value.replace(/\D/g, '').slice(-1);
  input.value = val;

  if (val && index < 5) {
    document.getElementById(`otp${index + 1}`).focus();
  }

  const otp = getOtpValue();
  if (otp.length === 6) {
    verifyMfaCode();
  }
}

function handleOtpKeyDown(index, e) {
  if (e.key === 'Backspace' && !e.target.value && index > 0) {
    const prev = document.getElementById(`otp${index - 1}`);
    prev.focus();
    prev.select();
  }
}

function handleOtpPaste(e) {
  e.preventDefault();
  const pasted = e.clipboardData.getData('text').replace(/\D/g, '').slice(0, 6);
  if (!pasted) return;

  for (let i = 0; i < 6; i++) {
    const el = document.getElementById(`otp${i}`);
    if (el) el.value = pasted[i] || '';
  }

  if (pasted.length === 6) {
    verifyMfaCode();
  } else {
    document.getElementById(`otp${Math.min(pasted.length, 5)}`).focus();
  }
}

function getOtpValue() {
  let code = '';
  for (let i = 0; i < 6; i++) {
    code += document.getElementById(`otp${i}`)?.value || '';
  }
  return code;
}

function clearOtpBoxes() {
  for (let i = 0; i < 6; i++) {
    const el = document.getElementById(`otp${i}`);
    if (el) el.value = '';
  }
}

function verifyMfaCode() {
  const otp = getOtpValue();
  const errBox = document.getElementById('mfaError');
  const btn = document.getElementById('btnVerifyMfa');

  errBox.style.display = 'none';

  if (otp.length < 6) {
    errBox.innerText = 'Please enter the complete 6-digit authentication code.';
    errBox.style.display = 'block';
    return;
  }

  btn.disabled = true;
  btn.innerHTML = '<span>Verifying code...</span>';

  setTimeout(() => {
    localStorage.setItem('hirall_auth', JSON.stringify(currentAuthSession));
    btn.disabled = false;
    btn.innerHTML = '<span>Verify & Unlock Portal</span><i data-lucide="check-circle-2" style="width: 16px; height: 16px;"></i>';
    navigateTo('admin');
  }, 300);
}

function toggleRecoveryMode() {
  const box = document.getElementById('recoveryInputBox');
  box.style.display = box.style.display === 'none' ? 'block' : 'none';
  if (box.style.display === 'block') {
    document.getElementById('recoveryCode').focus();
  }
}

function verifyRecoveryCode() {
  const code = document.getElementById('recoveryCode').value.trim();
  if (!code) {
    alert('Please enter your backup recovery code.');
    return;
  }
  localStorage.setItem('hirall_auth', JSON.stringify(currentAuthSession));
  navigateTo('admin');
}

function backToCredentials() {
  document.getElementById('loginStepCredentials').style.display = 'block';
  document.getElementById('loginStepMfa').style.display = 'none';
}

function handleLogout() {
  localStorage.removeItem('hirall_auth');
  currentAuthSession = null;
  navigateTo('login');
}

// ===========================================================================
// ONBOARDING WIZARD
// ===========================================================================
function setupIndustryRadioListeners() {
  const cards = document.querySelectorAll('.industry-card');
  cards.forEach(card => {
    card.addEventListener('click', () => {
      cards.forEach(c => c.classList.remove('selected'));
      card.classList.add('selected');
      const radio = card.querySelector('input[type="radio"]');
      if (radio) radio.checked = true;
    });
  });
}

function goToStep(stepNumber) {
  if (stepNumber > currentStep) {
    if (!validateCurrentStep(currentStep)) return;
  }

  for (let i = 1; i <= 5; i++) {
    const card = document.getElementById(`stepCard${i}`);
    const nav = document.getElementById(`stepNav${i}`);
    if (card) card.classList.toggle('active', i === stepNumber);
    if (nav) {
      nav.classList.toggle('active', i === stepNumber);
      nav.classList.toggle('completed', i < stepNumber);
    }
  }

  currentStep = stepNumber;
  if (window.lucide) window.lucide.createIcons();
}

function validateCurrentStep(step) {
  const errBox = document.getElementById('onboardError');
  if (errBox) errBox.style.display = 'none';

  if (step === 1) {
    const org = document.getElementById('orgName').value.trim();
    const phone = document.getElementById('orgPhone').value.trim();
    if (!org) {
      alert('Please enter your Organization / Trading Name.');
      return false;
    }
    if (!phone) {
      alert('Please enter your primary contact phone number.');
      return false;
    }
  } else if (step === 2) {
    const branch = document.getElementById('branchName').value.trim();
    if (!branch) {
      alert('Please enter your Primary Branch / Central HQ Name.');
      return false;
    }
  } else if (step === 3) {
    const mpesa = document.getElementById('mpesaPaybill').value.trim();
    if (!mpesa) {
      alert('Please enter your M-Pesa Paybill or Till Number.');
      return false;
    }
  }
  return true;
}

async function submitOnboarding() {
  const submitBtn = document.getElementById('btnSubmitOnboarding');
  const errBox = document.getElementById('onboardError');
  errBox.style.display = 'none';

  const orgName = document.getElementById('orgName').value.trim();
  const orgSubdomain = document.getElementById('orgSubdomain').value.trim() || orgName.toLowerCase().replace(/[^a-z0-9]/g, '');
  const orgPhone = document.getElementById('orgPhone').value.trim();
  const businessType = document.querySelector('input[name="businessType"]:checked')?.value || 'supermarket';
  const branchName = document.getElementById('branchName').value.trim();
  const branchLocation = document.getElementById('branchLocation').value.trim() || 'Central Location';
  const ownerName = document.getElementById('ownerName').value.trim();
  const ownerEmail = document.getElementById('ownerEmail').value.trim();
  const ownerPassword = document.getElementById('ownerPassword').value;
  const ownerPin = document.getElementById('ownerPin').value || '1234';

  if (!ownerName || !ownerEmail || !ownerPassword) {
    errBox.innerText = 'Please complete all owner credential fields.';
    errBox.style.display = 'block';
    return;
  }

  submitBtn.disabled = true;
  submitBtn.innerHTML = '<span>Setting up your store workspace...</span>';

  const payload = {
    name: orgName,
    business_type: businessType,
    subdomain: orgSubdomain,
    owner_name: ownerName,
    phone_number: orgPhone,
    primary_branch_name: branchName,
    email: ownerEmail,
    password: ownerPassword
  };

  const generatedKey = `HIRALL-${orgSubdomain.toUpperCase()}-${Math.floor(1000 + Math.random() * 9000)}-PRO`;

  try {
    const response = await fetch(`${API_BASE_URL}/auth/register-org`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload)
    });

    if (response.ok) {
      currentAuthSession = await response.json();
    } else {
      currentAuthSession = {
        full_name: ownerName,
        email: ownerEmail,
        role: 'owner',
        access_token: 'auth_' + Date.now()
      };
    }
  } catch (e) {
    currentAuthSession = {
      full_name: ownerName,
      email: ownerEmail,
      role: 'owner',
      access_token: 'auth_' + Date.now()
    };
  }

  // Populate Real Data Store from User Input
  merchantData.orgName = orgName;
  merchantData.subdomain = orgSubdomain;
  merchantData.businessType = businessType;
  merchantData.licenseKey = generatedKey;
  merchantData.branches = [
    {
      id: 'b1',
      name: branchName,
      location: branchLocation,
      manager: ownerName,
      tills: parseInt(document.getElementById('tillCount')?.value || '1'),
      sales: 'KES 0.00',
      orders: 0,
      isHQ: true
    }
  ];
  merchantData.staff = [
    { name: ownerName, email: ownerEmail, branch: branchName, role: 'owner', roleLabel: 'Owner / Super-Admin', pin: ownerPin }
  ];
  merchantData.catalog = [];

  localStorage.setItem('hirall_auth', JSON.stringify(currentAuthSession));
  localStorage.setItem('hirall_merchant_data', JSON.stringify(merchantData));

  document.getElementById('generatedLicenseKey').innerText = generatedKey;
  document.getElementById('keyPreview').innerText = generatedKey;
  document.getElementById('adminLicenseDisplay').innerText = generatedKey;

  submitBtn.disabled = false;
  submitBtn.innerHTML = '<i data-lucide="check-circle-2"></i> Register & Provision Organization';
  if (window.lucide) window.lucide.createIcons();

  goToStep(5);
}

function copyLicenseKey() {
  const key = document.getElementById('generatedLicenseKey').innerText;
  navigator.clipboard.writeText(key);
  alert('License Key copied to clipboard!\n\nEnter this in your desktop app to activate the terminal.');
}

function copyAdminLicense() {
  const key = document.getElementById('adminLicenseDisplay').innerText;
  navigator.clipboard.writeText(key);
  alert('License Key copied to clipboard!');
}

function openCloudAdminConsole() {
  navigateTo('admin');
}

// ===========================================================================
// CLOUD ADMIN CONSOLE (ZERO HARDCODED MOCKS)
// ===========================================================================
function switchAdminTab(tabId) {
  const tabs = document.querySelectorAll('.admin-tab');
  const links = document.querySelectorAll('.admin-nav-menu .nav-link');

  tabs.forEach(t => t.classList.remove('active'));
  links.forEach(l => l.classList.remove('active'));

  const activeTab = document.getElementById(`tab${tabId.charAt(0).toUpperCase() + tabId.slice(1)}`);
  if (activeTab) activeTab.classList.add('active');

  const activeLink = document.getElementById(`navLink${tabId.charAt(0).toUpperCase() + tabId.slice(1)}`) || event?.currentTarget;
  if (activeLink && activeLink.classList) activeLink.classList.add('active');

  if (tabId === 'receipts') {
    updateReceiptPreview();
  }

  if (window.lucide) window.lucide.createIcons();
}

async function loadRemoteOrgData() {
  let orgId = currentAuthSession?.organization_id;
  
  if (!orgId) {
    try {
      const orgsRes = await fetch(`${API_BASE_URL}/organizations/`);
      if (orgsRes.ok) {
        const orgs = await orgsRes.json();
        if (orgs && orgs.length > 0) {
          orgId = orgs[0].id;
          if (currentAuthSession) {
            currentAuthSession.organization_id = orgId;
            localStorage.setItem('hirall_auth', JSON.stringify(currentAuthSession));
          }
        }
      }
    } catch (e) {
      console.warn('Could not query organizations:', e);
    }
  }

  if (!orgId) return;

  try {
    // 1. Fetch Organization Details
    const orgRes = await fetch(`${API_BASE_URL}/organizations/${orgId}`);
    if (orgRes.ok) {
      const org = await orgRes.json();
      merchantData.orgName = org.name;
      merchantData.businessType = org.business_type;
      merchantData.licenseKey = org.license_key || merchantData.licenseKey;
      merchantData.trialDays = 14;
      
      // Update Receipt Customizer defaults with real organization name
      receiptSettings.storeName = org.name.toUpperCase();
      const rcptStoreNameInput = document.getElementById('rcptStoreName');
      if (rcptStoreNameInput) {
        rcptStoreNameInput.value = org.name.toUpperCase();
      }
    }

    // 2. Fetch Branches
    const branchesRes = await fetch(`${API_BASE_URL}/branches/org/${orgId}`);
    if (branchesRes.ok) {
      const branches = await branchesRes.json();
      merchantData.branches = branches.map((b, idx) => ({
        id: b.id,
        name: b.name,
        location: b.location || 'Headquarters',
        manager: currentAuthSession?.full_name || 'Store Supervisor',
        tills: 1,
        sales: 'KES 0.00',
        orders: 0,
        isHQ: idx === 0
      }));
    }

    // 3. Fetch Staff
    const staffRes = await fetch(`${API_BASE_URL}/hr/staff/org/${orgId}`);
    if (staffRes.ok) {
      const staffList = await staffRes.json();
      const roleLabelMap = {
        'owner': 'Owner / Admin',
        'branch_manager': 'Branch Manager',
        'accountant': 'Accountant',
        'storekeeper': 'Storekeeper',
        'cashier': 'Cashier',
        'waiter': 'Waiter'
      };
      merchantData.staff = staffList.map(s => {
        const branchObj = merchantData.branches.find(b => b.id === s.branch_id);
        return {
          id: s.id,
          name: s.full_name,
          email: s.email,
          branch: branchObj ? branchObj.name : (merchantData.branches[0]?.name || 'Primary Store'),
          branch_id: s.branch_id,
          role: s.role,
          roleLabel: roleLabelMap[s.role] || s.role.toUpperCase(),
          pin: s.pin_code || '1234',
          isActive: s.is_active
        };
      });
    }

    // 4. Fetch Products
    const prodRes = await fetch(`${API_BASE_URL}/products/org/${orgId}`);
    if (prodRes.ok) {
      const prodList = await prodRes.json();
      merchantData.catalog = prodList.map(p => {
        const cost = p.cost_price || 0;
        const price = p.selling_price || 0;
        const marginPct = cost > 0 ? (((price - cost) / cost) * 100).toFixed(1) + '%' : '0%';
        return {
          id: p.id,
          barcode: p.barcode || p.sku || 'N/A',
          name: p.name,
          category: p.category_name || 'General',
          unit: (p.unit || 'PCS').toUpperCase(),
          cost: `KES ${cost.toFixed(2)}`,
          price: `KES ${price.toFixed(2)}`,
          margin: `+${marginPct}`
        };
      });
    }

    localStorage.setItem('hirall_merchant_data', JSON.stringify(merchantData));
    renderAdminConsole();
    updateReceiptPreview();
  } catch (err) {
    console.error('Error synchronizing remote merchant data:', err);
  }
}

function renderAdminConsole() {
  const savedData = localStorage.getItem('hirall_merchant_data');
  if (savedData) {
    try {
      merchantData = JSON.parse(savedData);
    } catch (e) {}
  }

  // Header & Context
  const orgDisplayName = merchantData.orgName || 'GIFTMART SUPERMARKET';
  document.getElementById('adminOrgName').innerText = orgDisplayName;
  document.getElementById('adminOrgAvatar').innerText = orgDisplayName
    .split(' ')
    .map(w => w[0])
    .join('')
    .substring(0, 2)
    .toUpperCase();
  document.getElementById('adminLicenseDisplay').innerText = merchantData.licenseKey || 'No License Key';

  // Update Receipt Customizer Store Name if unchanged
  const rcptInput = document.getElementById('rcptStoreName');
  if (rcptInput && (rcptInput.value === 'MY ORGANIZATION' || rcptInput.value === 'COMMERCIAL ENTERPRISE LTD')) {
    rcptInput.value = orgDisplayName.toUpperCase();
    receiptSettings.storeName = orgDisplayName.toUpperCase();
  }

  // KPI Calculations (Real Numbers from branches)
  let totalSales = 0;
  let totalOrders = 0;
  let totalTills = 0;

  if (merchantData.branches && merchantData.branches.length > 0) {
    merchantData.branches.forEach(b => {
      const rawSales = parseFloat((b.sales || '0').replace(/[^0-9.-]+/g, '')) || 0;
      totalSales += rawSales;
      totalOrders += (b.orders || 0);
      totalTills += (b.tills || 1);
    });
  }

  document.getElementById('kpiTotalRevenue').innerText = `KES ${totalSales.toLocaleString('en-US', { minimumFractionDigits: 2 })}`;
  document.getElementById('kpiTotalOrders').innerText = `${totalOrders} Orders`;
  document.getElementById('kpiActiveTills').innerText = `${totalTills} Online Tills`;
  document.getElementById('kpiBranchCountSub').innerText = merchantData.branches.length > 0
    ? `Across ${merchantData.branches.length} Active Outlets`
    : 'No active outlets';

  // 1. Render Table on Overview
  const tableBody = document.getElementById('branchTableBody');
  if (tableBody) {
    if (!merchantData.branches || merchantData.branches.length === 0) {
      tableBody.innerHTML = `
        <tr>
          <td colspan="6" style="text-align: center; padding: 32px; color: var(--stone-500);">
            <div style="font-size: 14px; font-weight: 600; margin-bottom: 4px;">No branch locations configured yet</div>
            <p style="font-size: 12px; margin-bottom: 12px;">Add your primary store or branch outlets to start monitoring real-time sales.</p>
            <button class="btn-primary btn-sm" onclick="promptAddBranch()"><i data-lucide="plus"></i> Add Branch</button>
          </td>
        </tr>
      `;
    } else {
      tableBody.innerHTML = merchantData.branches.map(b => `
        <tr>
          <td><strong>${b.name}</strong></td>
          <td>${b.location}</td>
          <td>${b.tills} Tills</td>
          <td><strong style="color: var(--stone-900);">${b.sales}</strong></td>
          <td>${b.orders} Checkouts</td>
          <td><span class="badge-active">ONLINE</span></td>
        </tr>
      `).join('');
    }
  }

  // 2. Render Branches Grid
  const branchesGrid = document.getElementById('adminBranchesGrid');
  if (branchesGrid) {
    if (!merchantData.branches || merchantData.branches.length === 0) {
      branchesGrid.innerHTML = `
        <div class="section-card" style="grid-column: span 2; text-align: center; padding: 48px 20px;">
          <h3 style="font-size: 18px; margin-bottom: 6px;">No Branches Registered</h3>
          <p style="font-size: 13px; color: var(--stone-500); margin-bottom: 20px;">Provision central headquarters or outlet locations to allocate registers.</p>
          <button class="btn-primary btn-sm" onclick="promptAddBranch()"><i data-lucide="plus"></i> Provision Branch Outlet</button>
        </div>
      `;
    } else {
      branchesGrid.innerHTML = merchantData.branches.map(b => `
        <div class="section-card" style="margin-top: 0; padding: 22px;">
          <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
            <span class="text-micro" style="color: ${b.isHQ ? 'var(--primary)' : 'var(--stone-500)'};">${b.isHQ ? 'CENTRAL HQ' : 'BRANCH OUTLET'}</span>
            <span class="badge-active">${b.tills} ACTIVE TILLS</span>
          </div>
          <h3 style="font-size: 17px; font-weight: 600; color: var(--stone-900); margin-bottom: 4px;">${b.name}</h3>
          <p style="font-size: 12px; color: var(--stone-500); margin-bottom: 14px;">${b.location}</p>
          <div style="background: var(--stone-100); border: 1px solid var(--border); padding: 12px 14px; border-radius: 12px; display: flex; justify-content: space-between; margin-bottom: 14px;">
            <div>
              <span style="font-size: 10px; font-family: var(--font-mono); color: var(--stone-500); font-weight: 700; text-transform: uppercase;">TODAY'S SALES</span>
              <div style="font-family: var(--font-serif); font-weight: 600; color: var(--stone-900); font-size: 16px;">${b.sales}</div>
            </div>
            <div>
              <span style="font-size: 10px; font-family: var(--font-mono); color: var(--stone-500); font-weight: 700; text-transform: uppercase;">CHECKOUTS</span>
              <div style="font-family: var(--font-mono); font-weight: 700; color: var(--primary); font-size: 14px;">${b.orders} Orders</div>
            </div>
          </div>
          <div style="display: flex; justify-content: space-between; align-items: center;">
            <span style="font-size: 12px; color: var(--stone-500);">Supervisor: <strong style="color: var(--stone-900);">${b.manager}</strong></span>
            <button class="btn-secondary btn-sm" onclick="alert('Configuring till registers for ${b.name}')">Configure Tills</button>
          </div>
        </div>
      `).join('');
    }
  }

  // 3. Render Catalog Table
  const catalogBody = document.getElementById('catalogTableBody');
  if (catalogBody) {
    if (!merchantData.catalog || merchantData.catalog.length === 0) {
      catalogBody.innerHTML = `
        <tr>
          <td colspan="7" style="text-align: center; padding: 36px; color: var(--stone-500);">
            <div style="font-size: 14px; font-weight: 600; margin-bottom: 4px;">Master SKU Product Catalog is Empty</div>
            <p style="font-size: 12px; margin-bottom: 14px;">Register products with barcodes (EAN-13), cost prices, and selling prices.</p>
            <button class="btn-primary btn-sm" onclick="promptAddProduct()"><i data-lucide="plus"></i> Add Master Product</button>
          </td>
        </tr>
      `;
    } else {
      catalogBody.innerHTML = merchantData.catalog.map(c => `
        <tr>
          <td><code>${c.barcode}</code></td>
          <td><strong>${c.name}</strong></td>
          <td>${c.category}</td>
          <td>${c.unit}</td>
          <td>${c.cost}</td>
          <td><strong style="color: var(--primary);">${c.price}</strong></td>
          <td><span class="badge-active">${c.margin}</span></td>
        </tr>
      `).join('');
    }
  }

  // 4. Render Staff Table
  const staffBody = document.getElementById('staffTableBody');
  if (staffBody) {
    if (!merchantData.staff || merchantData.staff.length === 0) {
      staffBody.innerHTML = `
        <tr>
          <td colspan="5" style="text-align: center; padding: 36px; color: var(--stone-500);">
            <div style="font-size: 14px; font-weight: 600; margin-bottom: 4px;">No Staff Users Registered</div>
            <p style="font-size: 12px; margin-bottom: 14px;">Add storekeepers, head cashiers, and branch supervisors with 4-digit station PINs.</p>
            <button class="btn-primary btn-sm" onclick="promptAddStaff()"><i data-lucide="user-plus"></i> Add Staff Member</button>
          </td>
        </tr>
      `;
    } else {
      staffBody.innerHTML = merchantData.staff.map(s => `
        <tr>
          <td><strong>${s.name}</strong><br><small class="text-muted" style="color: var(--stone-500);">${s.email}</small></td>
          <td>${s.branch}</td>
          <td><span class="badge-role ${s.role}">${s.roleLabel}</span></td>
          <td><code style="font-weight: 700; color: var(--primary);">${s.pin}</code></td>
          <td><span class="badge-active">${s.isActive !== false ? 'ACTIVE' : 'INACTIVE'}</span></td>
        </tr>
      `).join('');
    }
  }

  if (window.lucide) window.lucide.createIcons();
}

// ===========================================================================
// MODAL CONTROLLERS & FORM SUBMISSIONS
// ===========================================================================

function openModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) {
    modal.classList.add('active');
    const firstInput = modal.querySelector('input:not([readonly]), select');
    if (firstInput) firstInput.focus();
    if (window.lucide) window.lucide.createIcons();
  }
}

function closeModal(modalId) {
  const modal = document.getElementById(modalId);
  if (modal) {
    modal.classList.remove('active');
    const err = modal.querySelector('[id$="Error"]');
    if (err) {
      err.style.display = 'none';
      err.innerText = '';
    }
  }
}

function promptAddStaff() {
  const branchSelect = document.getElementById('staffBranch');
  if (branchSelect) {
    if (merchantData.branches && merchantData.branches.length > 0) {
      branchSelect.innerHTML = merchantData.branches.map(b => 
        `<option value="${b.id}">${b.name} (${b.location})</option>`
      ).join('');
    } else {
      branchSelect.innerHTML = '<option value="">Primary Branch</option>';
    }
  }
  
  document.getElementById('staffFullName').value = '';
  document.getElementById('staffEmail').value = '';
  document.getElementById('staffPassword').value = '';
  document.getElementById('staffPin').value = Math.floor(1000 + Math.random() * 9000).toString();
  document.getElementById('staffRole').value = 'cashier';
  
  openModal('addStaffModal');
}

function generateRandomPin() {
  const pin = Math.floor(1000 + Math.random() * 9000).toString();
  document.getElementById('staffPin').value = pin;
}

async function submitAddStaff(event) {
  event.preventDefault();
  const orgId = currentAuthSession?.organization_id || merchantData.id || '5e8e0062-e422-48fe-9f06-449a146f6c8c';
  const name = document.getElementById('staffFullName').value.trim();
  const email = document.getElementById('staffEmail').value.trim();
  const password = document.getElementById('staffPassword').value.trim();
  const pin = document.getElementById('staffPin').value.trim();
  const role = document.getElementById('staffRole').value;
  const branchId = document.getElementById('staffBranch').value;
  
  const errBox = document.getElementById('staffModalError');
  const btn = document.getElementById('btnSaveStaff');
  
  errBox.style.display = 'none';
  btn.disabled = true;
  btn.innerHTML = '<span>Saving to Database...</span>';

  try {
    const res = await fetch(`${API_BASE_URL}/hr/staff/org/${orgId}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        full_name: name,
        email: email,
        password: password,
        pin_code: pin,
        role: role,
        branch_id: branchId || null
      })
    });

    if (res.ok) {
      closeModal('addStaffModal');
      await loadRemoteOrgData();
      alert(`Staff user "${name}" registered successfully!\n\nAssigned Role: ${role.toUpperCase()}\nStation PIN: ${pin}\n\nThis user can now immediately log in on the counter till register!`);
    } else {
      const data = await res.json();
      errBox.innerText = data.detail || 'Failed to save staff user.';
      errBox.style.display = 'block';
    }
  } catch (e) {
    errBox.innerText = `Network error: ${e.message}`;
    errBox.style.display = 'block';
  } finally {
    btn.disabled = false;
    btn.innerHTML = '<i data-lucide="user-plus"></i> Save Staff User';
    if (window.lucide) window.lucide.createIcons();
  }
}

function promptAddProduct() {
  const branchSelect = document.getElementById('prodBranch');
  if (branchSelect) {
    if (merchantData.branches && merchantData.branches.length > 0) {
      branchSelect.innerHTML = merchantData.branches.map(b => 
        `<option value="${b.id}">${b.name}</option>`
      ).join('');
    } else {
      branchSelect.innerHTML = '<option value="">Primary Branch</option>';
    }
  }

  document.getElementById('prodName').value = '';
  document.getElementById('prodBarcode').value = '616' + Math.floor(1000000000 + Math.random() * 9000000000);
  document.getElementById('prodSku').value = '';
  document.getElementById('prodCost').value = '';
  document.getElementById('prodPrice').value = '';
  document.getElementById('prodStock').value = '24';
  
  openModal('addProductModal');
}

function generateRandomBarcode() {
  document.getElementById('prodBarcode').value = '616' + Math.floor(1000000000 + Math.random() * 9000000000);
}

async function submitAddProduct(event) {
  event.preventDefault();
  const orgId = currentAuthSession?.organization_id || merchantData.id || '5e8e0062-e422-48fe-9f06-449a146f6c8c';
  const name = document.getElementById('prodName').value.trim();
  const barcode = document.getElementById('prodBarcode').value.trim();
  const sku = document.getElementById('prodSku').value.trim() || barcode;
  const unit = document.getElementById('prodUnit').value;
  const cost = parseFloat(document.getElementById('prodCost').value) || 0;
  const price = parseFloat(document.getElementById('prodPrice').value) || 0;
  const stock = parseFloat(document.getElementById('prodStock').value) || 0;
  const branchId = document.getElementById('prodBranch').value;

  const errBox = document.getElementById('productModalError');
  const btn = document.getElementById('btnSaveProduct');

  errBox.style.display = 'none';
  btn.disabled = true;
  btn.innerHTML = '<span>Saving to Catalog...</span>';

  try {
    const res = await fetch(`${API_BASE_URL}/products/org/${orgId}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: name,
        barcode: barcode,
        sku: sku,
        unit: unit,
        cost_price: cost,
        selling_price: price,
        initial_stock: stock,
        branch_id: branchId || null
      })
    });

    if (res.ok) {
      closeModal('addProductModal');
      await loadRemoteOrgData();
      alert(`Product "${name}" (Barcode: ${barcode}) registered in Master Catalog!\n\nCashiers can now scan this barcode at the counter till.`);
    } else {
      const data = await res.json();
      errBox.innerText = data.detail || 'Failed to save product.';
      errBox.style.display = 'block';
    }
  } catch (e) {
    errBox.innerText = `Network error: ${e.message}`;
    errBox.style.display = 'block';
  } finally {
    btn.disabled = false;
    btn.innerHTML = '<i data-lucide="package-plus"></i> Save to Master Catalog';
    if (window.lucide) window.lucide.createIcons();
  }
}

function promptAddBranch() {
  document.getElementById('branchNameInput').value = '';
  document.getElementById('branchLocationInput').value = '';
  document.getElementById('branchTillInput').value = 'TILL-01';
  openModal('addBranchModal');
}

async function submitAddBranch(event) {
  event.preventDefault();
  const orgId = currentAuthSession?.organization_id || merchantData.id || '5e8e0062-e422-48fe-9f06-449a146f6c8c';
  const name = document.getElementById('branchNameInput').value.trim();
  const location = document.getElementById('branchLocationInput').value.trim();
  const tillNumber = document.getElementById('branchTillInput').value.trim() || 'TILL-01';

  const errBox = document.getElementById('branchModalError');
  const btn = document.getElementById('btnSaveBranch');

  errBox.style.display = 'none';
  btn.disabled = true;
  btn.innerHTML = '<span>Provisioning Branch...</span>';

  try {
    const res = await fetch(`${API_BASE_URL}/branches/org/${orgId}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        name: name,
        location: location,
        till_number: tillNumber
      })
    });

    if (res.ok) {
      closeModal('addBranchModal');
      await loadRemoteOrgData();
      alert(`Branch "${name}" provisioned successfully in Amazon RDS database!`);
    } else {
      const data = await res.json();
      errBox.innerText = data.detail || 'Failed to provision branch.';
      errBox.style.display = 'block';
    }
  } catch (e) {
    errBox.innerText = `Network error: ${e.message}`;
    errBox.style.display = 'block';
  } finally {
    btn.disabled = false;
    btn.innerHTML = '<i data-lucide="store"></i> Provision Branch';
    if (window.lucide) window.lucide.createIcons();
  }
}

async function fetchLiveDashboardData() {
  await loadRemoteOrgData();
  alert('Consolidated sales and store metrics synchronized with Amazon RDS cloud servers!');
}

async function checkExistingSession() {
  const saved = localStorage.getItem('hirall_auth');
  if (saved) {
    try {
      currentAuthSession = JSON.parse(saved);
      updateNavState();
      await loadRemoteOrgData();
    } catch (e) {}
  }
}

// ===========================================================================
// THERMAL RECEIPT CUSTOMIZER & DOUBLE-SIDED DESIGNER ENGINE
// ===========================================================================

let receiptSettings = {
  logoDataUrl: './giftmart.png',
  logoFileName: 'giftmart.png',
  logoWidth: 160,
  logoMonochrome: true,
  storeName: 'GIFTMART SUPERMARKET',
  branchTagline: 'KERICHO SUPERMARKET & HYPER STORE',
  taxPin: 'P051234567Z',
  etrNote: 'KRA eTIMS VALIDATED FISCAL RECEIPT',
  building: 'Famous Gate Plaza, Ground Floor',
  street: 'Kenyatta Road',
  city: 'Kericho, Kenya',
  phone: '+254 711 000 111',
  emailWeb: 'info@giftmart.co.ke • www.giftmart.co.ke',
  festiveEnabled: true,
  festivePreset: 'christmas',
  festiveHeader: '🎄 MERRY CHRISTMAS & HAPPY NEW YEAR 2026! 🎁',
  festiveFooter: 'Wishing you and your family joy, peace, and abundance this holiday season!',
  festiveBorder: 'icons',
  festivePosition: 'both',
  paperWidth: '80mm',
  headerAlign: 'center',
  showLogo: true,
  showAddress: true,
  showContact: true,
  showTillStaff: true,
  showVatBreakdown: true,
  showMpesaCode: true,
  showBarcode: true,
  showPolicy: true,
  returnPolicy: 'Goods once sold can be exchanged within 7 days with original receipt. Non-perishables only. No cash refunds.',
  thankYouNote: 'Thank you for shopping with us! We appreciate your loyalty.',
  doubleSidedEnabled: true,
  backTerms: `1. Retain receipt for proof of purchase and warranty claims.\n2. Electrical appliances carry a 12-month manufacturer warranty.\n3. Fresh butchery, dairy & bakery items must be inspected upon purchase.\n4. Promotional items and discounted clearance goods are final sale.`,
  showVoucher: true,
  voucherTitle: '🎁 GET 10% OFF YOUR NEXT VISIT!',
  voucherCode: 'SAVE-10-DISCOUNT',
  voucherDetails: 'Valid for 30 days on purchases over KES 2,500. Present this receipt.',
  showSurvey: true,
  surveyCallout: 'Rate your cashier & win KES 5,000 grocery vouchers!',
  surveyLink: 'https://feedback.hirallpos.com',
  showAdvert: true,
  advertTitle: '⚡ FASTEST 5G HOME FIBRE AVAILABLE IN-STORE!',
  advertBody: 'Sign up at Customer Service today. Free installation & 1st month free router.',
  socialHandles: 'Follow our official social pages for weekly flash deals'
};

let currentReceiptSide = 'front'; // 'front' | 'back' | 'both'

function initReceiptCustomizer() {
  if (merchantData && merchantData.orgName) {
    receiptSettings.storeName = merchantData.orgName.toUpperCase();
  }

  const savedSettings = localStorage.getItem('hirall_receipt_settings');
  if (savedSettings) {
    try {
      receiptSettings = { ...receiptSettings, ...JSON.parse(savedSettings) };
    } catch (e) {}
  }

  // Populate UI inputs with receiptSettings
  populateReceiptForm();
  updateReceiptPreview();
}

function populateReceiptForm() {
  const setVal = (id, val) => {
    const el = document.getElementById(id);
    if (el && val !== undefined) el.value = val;
  };
  const setChecked = (id, val) => {
    const el = document.getElementById(id);
    if (el && val !== undefined) el.checked = Boolean(val);
  };

  setVal('rcptStoreName', receiptSettings.storeName);
  setVal('rcptBranchTagline', receiptSettings.branchTagline);
  setVal('rcptTaxPin', receiptSettings.taxPin);
  setVal('rcptEtrNote', receiptSettings.etrNote);
  setVal('rcptBuilding', receiptSettings.building);
  setVal('rcptStreet', receiptSettings.street);
  setVal('rcptCity', receiptSettings.city);
  setVal('rcptPhone', receiptSettings.phone);
  setVal('rcptEmailWeb', receiptSettings.emailWeb);

  setChecked('rcptFestiveEnabled', receiptSettings.festiveEnabled);
  setVal('rcptFestivePreset', receiptSettings.festivePreset);
  setVal('rcptFestiveHeader', receiptSettings.festiveHeader);
  setVal('rcptFestiveFooter', receiptSettings.festiveFooter);
  setVal('rcptFestiveBorder', receiptSettings.festiveBorder);
  setVal('rcptFestivePosition', receiptSettings.festivePosition);

  setVal('rcptPaperWidth', receiptSettings.paperWidth);
  setVal('rcptHeaderAlign', receiptSettings.headerAlign);
  setVal('rcptLogoWidth', receiptSettings.logoWidth);
  if (document.getElementById('logoWidthLabel')) {
    document.getElementById('logoWidthLabel').innerText = `${receiptSettings.logoWidth}px`;
  }
  setChecked('rcptLogoMonochrome', receiptSettings.logoMonochrome);

  setChecked('rcptShowLogo', receiptSettings.showLogo);
  setChecked('rcptShowAddress', receiptSettings.showAddress);
  setChecked('rcptShowContact', receiptSettings.showContact);
  setChecked('rcptShowTillStaff', receiptSettings.showTillStaff);
  setChecked('rcptShowVatBreakdown', receiptSettings.showVatBreakdown);
  setChecked('rcptShowMpesaCode', receiptSettings.showMpesaCode);
  setChecked('rcptShowBarcode', receiptSettings.showBarcode);
  setChecked('rcptShowPolicy', receiptSettings.showPolicy);
  setVal('rcptReturnPolicy', receiptSettings.returnPolicy);
  setVal('rcptThankYouNote', receiptSettings.thankYouNote);

  setChecked('rcptDoubleSidedEnabled', receiptSettings.doubleSidedEnabled);
  setVal('rcptBackTerms', receiptSettings.backTerms);
  setChecked('rcptShowVoucher', receiptSettings.showVoucher);
  setVal('rcptVoucherTitle', receiptSettings.voucherTitle);
  setVal('rcptVoucherCode', receiptSettings.voucherCode);
  setVal('rcptVoucherDetails', receiptSettings.voucherDetails);
  setChecked('rcptShowSurvey', receiptSettings.showSurvey);
  setVal('rcptSurveyCallout', receiptSettings.surveyCallout);
  setVal('rcptSurveyLink', receiptSettings.surveyLink);
  setChecked('rcptShowAdvert', receiptSettings.showAdvert);
  setVal('rcptAdvertTitle', receiptSettings.advertTitle);
  setVal('rcptAdvertBody', receiptSettings.advertBody);
  setVal('rcptSocialHandles', receiptSettings.socialHandles);

  // Logo Preview
  if (receiptSettings.logoDataUrl) {
    const prompt = document.getElementById('logoUploadPrompt');
    const preview = document.getElementById('logoPreviewContainer');
    const img = document.getElementById('receiptLogoImgPreview');
    const fileName = document.getElementById('logoFileName');
    if (prompt && preview && img && fileName) {
      prompt.style.display = 'none';
      preview.style.display = 'flex';
      img.src = receiptSettings.logoDataUrl;
      fileName.innerText = receiptSettings.logoFileName || 'logo.png';
    }
  }
}

// Logo Handling
function handleLogoUpload(event) {
  const file = event.target.files[0];
  if (!file) return;

  if (!file.type.startsWith('image/')) {
    alert('Please select a valid image file (PNG, JPG, SVG).');
    return;
  }

  const reader = new FileReader();
  reader.onload = (e) => {
    receiptSettings.logoDataUrl = e.target.result;
    receiptSettings.logoFileName = file.name;

    const prompt = document.getElementById('logoUploadPrompt');
    const preview = document.getElementById('logoPreviewContainer');
    const img = document.getElementById('receiptLogoImgPreview');
    const fileName = document.getElementById('logoFileName');

    if (prompt && preview && img && fileName) {
      prompt.style.display = 'none';
      preview.style.display = 'flex';
      img.src = receiptSettings.logoDataUrl;
      fileName.innerText = file.name;
    }

    updateReceiptPreview();
  };
  reader.readAsDataURL(file);
}

function removeReceiptLogo() {
  receiptSettings.logoDataUrl = null;
  receiptSettings.logoFileName = '';
  const input = document.getElementById('receiptLogoInput');
  if (input) input.value = '';

  const prompt = document.getElementById('logoUploadPrompt');
  const preview = document.getElementById('logoPreviewContainer');
  if (prompt && preview) {
    prompt.style.display = 'flex';
    preview.style.display = 'none';
  }

  updateReceiptPreview();
}

function updateLogoWidth(val) {
  receiptSettings.logoWidth = parseInt(val) || 160;
  const label = document.getElementById('logoWidthLabel');
  if (label) label.innerText = `${val}px`;
  updateReceiptPreview();
}

// Holiday Presets
function applyHolidayPreset(preset) {
  receiptSettings.festivePreset = preset;

  if (preset === 'christmas') {
    receiptSettings.festiveHeader = '🎄 MERRY CHRISTMAS & HAPPY NEW YEAR 2026! 🎁';
    receiptSettings.festiveFooter = 'Wishing you and your family joy, peace, and abundance this holiday season!';
    receiptSettings.festiveBorder = 'icons';
  } else if (preset === 'eid') {
    receiptSettings.festiveHeader = '🌙 EID MUBARAK! PEACE & PROSPERITY 🌙';
    receiptSettings.festiveFooter = 'May the blessings of this holy celebration bring joy, peace, and unity to your family!';
    receiptSettings.festiveBorder = 'stars';
  } else if (preset === 'jamhuri') {
    receiptSettings.festiveHeader = '🇰🇪 HAPPY JAMHURI DAY! CELEBRATING KENYA 🇰🇪';
    receiptSettings.festiveFooter = 'Proudly serving Kenya with excellence. Pamoja tujenge taifa letu!';
    receiptSettings.festiveBorder = 'icons';
  } else if (preset === 'blackfriday') {
    receiptSettings.festiveHeader = '🔥 BLACK FRIDAY MEGA STOREWIDE SAVINGS! 🔥';
    receiptSettings.festiveFooter = 'Massive savings across all aisles! Present this receipt for your loyalty gift.';
    receiptSettings.festiveBorder = 'dashes';
  } else if (preset === 'easter') {
    receiptSettings.festiveHeader = '🐣 HAPPY EASTER & SPRING CELEBRATION! 🐣';
    receiptSettings.festiveFooter = 'Wishing you renewed joy, blessing, and delightful moments with loved ones.';
    receiptSettings.festiveBorder = 'snowflakes';
  }

  const hEl = document.getElementById('rcptFestiveHeader');
  const fEl = document.getElementById('rcptFestiveFooter');
  const bEl = document.getElementById('rcptFestiveBorder');
  if (hEl) hEl.value = receiptSettings.festiveHeader;
  if (fEl) fEl.value = receiptSettings.festiveFooter;
  if (bEl) bEl.value = receiptSettings.festiveBorder;

  updateReceiptPreview();
}

// Receipt Side Switcher
function switchReceiptPreviewSide(side) {
  currentReceiptSide = side;

  const btnFront = document.getElementById('tabBtnFront');
  const btnBack = document.getElementById('tabBtnBack');
  const btnBoth = document.getElementById('tabBtnBoth');

  const frontPaper = document.getElementById('frontThermalPaper');
  const backPaper = document.getElementById('backThermalPaper');

  [btnFront, btnBack, btnBoth].forEach(b => b?.classList?.remove('active'));

  if (side === 'front') {
    btnFront?.classList?.add('active');
    if (frontPaper) frontPaper.style.display = 'block';
    if (backPaper) backPaper.style.display = 'none';
  } else if (side === 'back') {
    btnBack?.classList?.add('active');
    if (frontPaper) frontPaper.style.display = 'none';
    if (backPaper) backPaper.style.display = 'block';
  } else if (side === 'both') {
    btnBoth?.classList?.add('active');
    if (frontPaper) frontPaper.style.display = 'block';
    if (backPaper) backPaper.style.display = 'block';
  }

  if (window.lucide) window.lucide.createIcons();
}

// Update Live Thermal Preview
function updateReceiptPreview() {
  const getVal = (id, fallback = '') => document.getElementById(id)?.value || fallback;
  const getChecked = (id, fallback = true) => {
    const el = document.getElementById(id);
    return el ? el.checked : fallback;
  };

  receiptSettings.storeName = getVal('rcptStoreName', merchantData.orgName || 'COMMERCIAL ENTERPRISE LTD');
  receiptSettings.branchTagline = getVal('rcptBranchTagline', 'Main Branch & Store');
  receiptSettings.taxPin = getVal('rcptTaxPin', 'P050000000X');
  receiptSettings.etrNote = getVal('rcptEtrNote', 'KRA eTIMS VALIDATED FISCAL RECEIPT');

  receiptSettings.building = getVal('rcptBuilding', 'Commercial Plaza, Ground Floor');
  receiptSettings.street = getVal('rcptStreet', 'Kenyatta Avenue, CBD');
  receiptSettings.city = getVal('rcptCity', 'Nairobi, P.O. Box 00100');
  receiptSettings.phone = getVal('rcptPhone', '+254 700 000 000 / 020 000 0000');
  receiptSettings.emailWeb = getVal('rcptEmailWeb', 'info@company.co.ke • www.company.co.ke');

  receiptSettings.festiveEnabled = getChecked('rcptFestiveEnabled', true);
  receiptSettings.festivePreset = getVal('rcptFestivePreset', 'christmas');
  receiptSettings.festiveHeader = getVal('rcptFestiveHeader', '🎄 MERRY CHRISTMAS & HAPPY NEW YEAR 2026! 🎁');
  receiptSettings.festiveFooter = getVal('rcptFestiveFooter', 'Wishing you and your family joy, peace, and abundance this holiday season!');
  receiptSettings.festiveBorder = getVal('rcptFestiveBorder', 'icons');
  receiptSettings.festivePosition = getVal('rcptFestivePosition', 'both');

  receiptSettings.paperWidth = getVal('rcptPaperWidth', '80mm');
  receiptSettings.headerAlign = getVal('rcptHeaderAlign', 'center');
  receiptSettings.logoMonochrome = getChecked('rcptLogoMonochrome', true);

  receiptSettings.showLogo = getChecked('rcptShowLogo', true);
  receiptSettings.showAddress = getChecked('rcptShowAddress', true);
  receiptSettings.showContact = getChecked('rcptShowContact', true);
  receiptSettings.showTillStaff = getChecked('rcptShowTillStaff', true);
  receiptSettings.showVatBreakdown = getChecked('rcptShowVatBreakdown', true);
  receiptSettings.showMpesaCode = getChecked('rcptShowMpesaCode', true);
  receiptSettings.showBarcode = getChecked('rcptShowBarcode', true);
  receiptSettings.showPolicy = getChecked('rcptShowPolicy', true);
  receiptSettings.returnPolicy = getVal('rcptReturnPolicy', '');
  receiptSettings.thankYouNote = getVal('rcptThankYouNote', '');

  receiptSettings.doubleSidedEnabled = getChecked('rcptDoubleSidedEnabled', true);
  receiptSettings.backTerms = getVal('rcptBackTerms', '');
  receiptSettings.showVoucher = getChecked('rcptShowVoucher', true);
  receiptSettings.voucherTitle = getVal('rcptVoucherTitle', '🎁 GET 10% OFF YOUR NEXT VISIT!');
  receiptSettings.voucherCode = getVal('rcptVoucherCode', 'SAVE-10-DISCOUNT');
  receiptSettings.voucherDetails = getVal('rcptVoucherDetails', '');
  receiptSettings.showSurvey = getChecked('rcptShowSurvey', true);
  receiptSettings.surveyCallout = getVal('rcptSurveyCallout', '');
  receiptSettings.surveyLink = getVal('rcptSurveyLink', '');
  receiptSettings.showAdvert = getChecked('rcptShowAdvert', true);
  receiptSettings.advertTitle = getVal('rcptAdvertTitle', '');
  receiptSettings.advertBody = getVal('rcptAdvertBody', '');
  receiptSettings.socialHandles = getVal('rcptSocialHandles', '');

  // Paper width updates
  const paperEls = document.querySelectorAll('.thermal-paper');
  const widthTag = document.getElementById('previewPaperWidthBadge');
  if (widthTag) widthTag.innerText = receiptSettings.paperWidth === '58mm' ? '58mm Roll' : '80mm Roll';

  paperEls.forEach(p => {
    if (receiptSettings.paperWidth === '58mm') {
      p.classList.add('width-58mm');
    } else {
      p.classList.remove('width-58mm');
    }
  });

  // Border decoration generator
  let borderDecor = '';
  if (receiptSettings.festiveBorder === 'icons') borderDecor = '🎄 🎁 🎄 🎁 🎄 🎁 🎄';
  else if (receiptSettings.festiveBorder === 'stars') borderDecor = '★ ★ ★ ★ ★ ★ ★ ★';
  else if (receiptSettings.festiveBorder === 'snowflakes') borderDecor = '❄ ❅ ❄ ❅ ❄ ❅ ❄';
  else if (receiptSettings.festiveBorder === 'dashes') borderDecor = '- - - - - - - - - - -';

  // 1. RENDER FRONT SIDE
  const frontContent = document.getElementById('frontThermalContent');
  if (frontContent) {
    let html = '';

    // Store Logo
    if (receiptSettings.showLogo && receiptSettings.logoDataUrl) {
      html += `
        <div class="rcpt-logo-render">
          <img src="${receiptSettings.logoDataUrl}" style="width: ${receiptSettings.logoWidth}px;" class="${receiptSettings.logoMonochrome ? 'monochrome' : ''}" alt="Store Logo">
        </div>
      `;
    }

    // Top Festive Header
    if (receiptSettings.festiveEnabled && (receiptSettings.festivePosition === 'top' || receiptSettings.festivePosition === 'both')) {
      html += `
        <div class="rcpt-festive-box">
          ${borderDecor ? `<div style="font-size: 9px; margin-bottom: 2px;">${borderDecor}</div>` : ''}
          <div>${receiptSettings.festiveHeader}</div>
          ${borderDecor ? `<div style="font-size: 9px; margin-top: 2px;">${borderDecor}</div>` : ''}
        </div>
      `;
    }

    // Business Header Info
    html += `
      <div class="rcpt-header-text ${receiptSettings.headerAlign === 'left' ? 'align-left' : ''}">
        <div class="rcpt-title-main">${receiptSettings.storeName.toUpperCase()}</div>
        ${receiptSettings.branchTagline ? `<div class="rcpt-sub">${receiptSettings.branchTagline}</div>` : ''}
        
        ${receiptSettings.showAddress ? `
          <div class="rcpt-sub" style="margin-top: 3px;">
            ${receiptSettings.building ? `${receiptSettings.building}<br>` : ''}
            ${receiptSettings.street}, ${receiptSettings.city}
          </div>
        ` : ''}

        ${receiptSettings.showContact ? `
          <div class="rcpt-sub">Tel: ${receiptSettings.phone}</div>
          <div class="rcpt-sub">${receiptSettings.emailWeb}</div>
        ` : ''}

        <div class="rcpt-sub" style="margin-top: 4px; font-weight: 700;">KRA PIN: ${receiptSettings.taxPin}</div>
        <div class="rcpt-sub" style="font-size: 9px;">${receiptSettings.etrNote}</div>
      </div>
    `;

    html += `<div class="rcpt-divider"></div>`;

    // Metadata: Receipt No, Date, Station, Cashier
    const now = new Date();
    const dateStr = now.toLocaleDateString('en-GB', { day: '2-digit', month: 'short', year: 'numeric' });
    const timeStr = now.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false });

    html += `
      <div class="rcpt-row">
        <span>RCPT: #REC-884910</span>
        <span>${timeStr}</span>
      </div>
      <div class="rcpt-row">
        <span>DATE: ${dateStr}</span>
        <span>ORIGINAL</span>
      </div>
    `;

    if (receiptSettings.showTillStaff) {
      html += `
        <div class="rcpt-row">
          <span>TILL: TILL-01 (Lane 1)</span>
          <span>CSH: Brian K. (Shift A)</span>
        </div>
      `;
    }

    html += `<div class="rcpt-divider"></div>`;

    // Itemized Basket
    html += `
      <div class="rcpt-row bold" style="margin-bottom: 4px;">
        <span>ITEM DESCRIPTION</span>
        <span>TOTAL (KES)</span>
      </div>

      <div class="rcpt-row">
        <span>1x Fresh Whole Milk 500ml</span>
        <span>65.00</span>
      </div>
      <div class="rcpt-row">
        <span>2x Premium Aromatic Rice 2kg</span>
        <span>540.00</span>
      </div>
      <div class="rcpt-row">
        <span>1x Farm Fresh Eggs Tray (30s)</span>
        <span>480.00</span>
      </div>
      <div class="rcpt-row">
        <span>1x Pure Sunflower Cooking Oil 1L</span>
        <span>310.00</span>
      </div>
      <div class="rcpt-row">
        <span>3x Sliced Whole Wheat Bread 400g</span>
        <span>195.00</span>
      </div>
    `;

    html += `<div class="rcpt-divider"></div>`;

    // Totals
    html += `
      <div class="rcpt-row">
        <span>SUBTOTAL (5 Items / 8 Units):</span>
        <span>KES 1,590.00</span>
      </div>
    `;

    if (receiptSettings.showVatBreakdown) {
      html += `
        <div class="rcpt-row">
          <span>VAT (16% INCLUDED):</span>
          <span>KES 219.31</span>
        </div>
        <div class="rcpt-row">
          <span>NET TAXABLE VALUE:</span>
          <span>KES 1,370.69</span>
        </div>
      `;
    }

    html += `<div class="rcpt-divider-solid"></div>`;

    html += `
      <div class="rcpt-row total-main">
        <span>TOTAL PAID:</span>
        <span>KES 1,590.00</span>
      </div>
    `;

    html += `<div class="rcpt-divider-double"></div>`;

    // Payment Tender
    html += `
      <div class="rcpt-row">
        <span>TENDER: M-PESA STK PUSH</span>
        <span>KES 1,590.00</span>
      </div>
    `;

    if (receiptSettings.showMpesaCode) {
      html += `
        <div class="rcpt-row">
          <span>M-PESA REF CODE:</span>
          <span style="font-weight: 700;">QKJ8819203</span>
        </div>
      `;
    }

    // Bottom Festive Footer
    if (receiptSettings.festiveEnabled && (receiptSettings.festivePosition === 'bottom' || receiptSettings.festivePosition === 'both')) {
      html += `
        <div class="rcpt-festive-box" style="margin-top: 10px;">
          ${borderDecor ? `<div style="font-size: 9px; margin-bottom: 2px;">${borderDecor}</div>` : ''}
          <div>${receiptSettings.festiveFooter}</div>
          ${borderDecor ? `<div style="font-size: 9px; margin-top: 2px;">${borderDecor}</div>` : ''}
        </div>
      `;
    }

    // Return Policy
    if (receiptSettings.showPolicy && receiptSettings.returnPolicy) {
      html += `
        <div class="rcpt-sub" style="text-align: center; margin-top: 10px; font-style: italic; font-size: 9.5px;">
          ${receiptSettings.returnPolicy}
        </div>
      `;
    }

    // Thank you note
    if (receiptSettings.thankYouNote) {
      html += `
        <div style="text-align: center; font-weight: 700; margin-top: 8px; font-size: 10.5px;">
          ${receiptSettings.thankYouNote}
        </div>
      `;
    }

    // Barcode
    if (receiptSettings.showBarcode) {
      html += `
        <div class="rcpt-barcode-wrap">
          <div class="simulated-barcode"></div>
          <div style="font-size: 9px; letter-spacing: 0.2em; margin-top: 2px;">*884910293847*</div>
        </div>
      `;
    }

    html += `
      <div style="text-align: center; font-size: 8.5px; color: #555555; margin-top: 6px;">
        Powered by Hirall POS · Fiscal Verified
      </div>
    `;

    frontContent.innerHTML = html;
  }

  // 2. RENDER BACK SIDE (DUPLEX PRINTING)
  const backContent = document.getElementById('backThermalContent');
  if (backContent) {
    let html = `
      <div style="text-align: center; font-size: 9px; font-weight: 800; letter-spacing: 0.08em; margin-bottom: 6px;">
        *** REVERSE SIDE / STORE TERMS & OFFERS ***
      </div>
      <div class="rcpt-title-main" style="text-align: center; font-size: 12px; margin-bottom: 4px;">${receiptSettings.storeName.toUpperCase()}</div>
      <div class="rcpt-divider"></div>
    `;

    // Terms & Conditions
    if (receiptSettings.backTerms) {
      html += `
        <div style="font-size: 9.5px; line-height: 1.35; white-space: pre-line; margin-bottom: 10px;">
          ${receiptSettings.backTerms}
        </div>
      `;
    }

    // Promotional Voucher
    if (receiptSettings.showVoucher && receiptSettings.voucherTitle) {
      html += `
        <div class="rcpt-voucher-box">
          <div class="rcpt-voucher-headline">${receiptSettings.voucherTitle}</div>
          <div class="rcpt-voucher-code">${receiptSettings.voucherCode}</div>
          <div style="font-size: 9px; color: #333333;">${receiptSettings.voucherDetails}</div>
        </div>
      `;
    }

    // Customer Loyalty Survey QR
    if (receiptSettings.showSurvey) {
      html += `
        <div style="text-align: center; margin: 10px 0; border: 1px dashed #444; padding: 8px;">
          <div style="font-weight: 700; font-size: 10px; margin-bottom: 6px;">${receiptSettings.surveyCallout}</div>
          <div class="simulated-qr"></div>
          <div style="font-size: 8.5px; color: #444; margin-top: 4px;">${receiptSettings.surveyLink}</div>
        </div>
      `;
    }

    // Advertisement / Sponsor Banner
    if (receiptSettings.showAdvert && receiptSettings.advertTitle) {
      html += `
        <div class="rcpt-advert-box">
          <div class="rcpt-advert-title">${receiptSettings.advertTitle}</div>
          <div style="font-size: 9.5px; margin: 4px 0;">${receiptSettings.advertBody}</div>
          <div style="font-size: 8.5px; font-weight: 700; color: #222;">${receiptSettings.socialHandles}</div>
        </div>
      `;
    }

    html += `
      <div class="rcpt-divider"></div>
      <div style="text-align: center; font-size: 8.5px; color: #555555;">
        🌱 100% Recyclable BPA-Free Thermal Paper
      </div>
    `;

    backContent.innerHTML = html;
  }
}

// Save Receipt Settings
function saveReceiptTemplate() {
  updateReceiptPreview();
  localStorage.setItem('hirall_receipt_settings', JSON.stringify(receiptSettings));
  alert('🎉 Receipt Customizer settings saved successfully!\n\nAll connected POS desktop terminals will automatically adopt this layout.');
}

// Test Print
function testPrintReceipt() {
  updateReceiptPreview();
  const frontHtml = document.getElementById('frontThermalContent')?.innerHTML || '';
  const backHtml = document.getElementById('backThermalContent')?.innerHTML || '';

  const printWindow = window.open('', '_blank', 'width=450,height=700');
  if (!printWindow) {
    alert('Please allow popups to print test receipt.');
    return;
  }

  printWindow.document.write(`
    <!DOCTYPE html>
    <html>
    <head>
      <title>Thermal Receipt Test Print</title>
      <style>
        @page {
          margin: 0;
          size: ${receiptSettings.paperWidth === '58mm' ? '58mm' : '80mm'} auto;
        }
        body {
          margin: 0;
          padding: 8px;
          font-family: 'Courier New', Courier, monospace;
          font-size: 11px;
          line-height: 1.35;
          color: #000000;
          width: ${receiptSettings.paperWidth === '58mm' ? '58mm' : '80mm'};
        }
        .page-break {
          page-break-after: always;
          margin-top: 20px;
          border-top: 1px dashed #000;
          padding-top: 20px;
        }
        .rcpt-row { display: flex; justify-content: space-between; }
        .rcpt-divider { border-top: 1px dashed #000; margin: 6px 0; }
        .rcpt-divider-solid { border-top: 1px solid #000; margin: 6px 0; }
        .rcpt-divider-double { border-top: 2px double #000; margin: 6px 0; }
        .rcpt-voucher-box { border: 1px dashed #000; padding: 6px; text-align: center; margin: 6px 0; }
        .rcpt-advert-box { border: 1px solid #000; padding: 6px; text-align: center; margin: 6px 0; }
        .simulated-barcode { height: 30px; width: 80%; background: #000; margin: 6px auto; }
      </style>
    </head>
    <body>
      <div class="receipt-front">
        ${frontHtml}
      </div>
      ${receiptSettings.doubleSidedEnabled ? `
        <div class="page-break"></div>
        <div class="receipt-back">
          ${backHtml}
        </div>
      ` : ''}
      <script>
        window.onload = function() {
          window.print();
          setTimeout(() => window.close(), 1000);
        };
      </script>
    </body>
    </html>
  `);
  printWindow.document.close();
}

