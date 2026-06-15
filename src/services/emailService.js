const { Resend } = require('resend');
const logger = require('./logger');

// Configure Resend
const resend = process.env.RESEND_API_KEY ? new Resend(process.env.RESEND_API_KEY) : null;

const FROM_ADDRESS = process.env.RESEND_FROM || 'Bitir Yemek <noreply@bitirgitsin.com>';

const sendMail = async (to, subject, html) => {
  if (!resend) {
    logger.info(`[Email] Resend yapılandırılmamış. Konu: ${subject}, Alıcı: ${to}`);
    return;
  }

  try {
    const { error } = await resend.emails.send({
      from: FROM_ADDRESS,
      to,
      subject,
      html,
    });
    if (error) {
      throw new Error(typeof error === 'string' ? error : (error.message || JSON.stringify(error)));
    }
    logger.info(`[Email] Gönderildi. Konu: ${subject}, Alıcı: ${to}`);
  } catch (error) {
    logger.error(`[Email] Gönderilemedi. Konu: ${subject}, Alıcı: ${to}, Hata: ${error.message}`);
    // Provide a user-friendly error message
    const friendlyError = new Error('E-posta gönderilemedi. Lütfen daha sonra tekrar deneyin.');
    friendlyError.statusCode = 502;
    throw friendlyError;
  }
};

const sendOtpEmail = async (email, code) => {
  await sendMail(email, 'Bitir Yemek - Giriş Kodu', `
    <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px;">
      <h2 style="color: #FF7043;">Giriş Kodunuz</h2>
      <p>Bitir Yemek'e giriş yapmak için aşağıdaki kodu uygulamaya girin:</p>
      <h1 style="letter-spacing: 8px; text-align: center; font-size: 36px; padding: 16px; background: #f5f5f5; border-radius: 8px; color: #333;">${code}</h1>
      <p style="color: #999; font-size: 12px; margin-top: 24px;">Bu kod 10 dakika geçerlidir. Eğer bu işlemi siz yapmadıysanız bu e-postayı dikkate almayın.</p>
    </div>
  `);
};

const sendVerificationEmail = async (email, token) => {
  const url = `${process.env.APP_URL || 'http://localhost:3000'}/api/auth/verify-email?token=${token}`;
  await sendMail(email, 'Bitir Yemek - E-posta Doğrulama', `
    <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px;">
      <h2 style="color: #FF7043;">E-posta Doğrulama</h2>
      <p>Hesabınızı doğrulamak için aşağıdaki bağlantıya tıklayın:</p>
      <a href="${url}" style="display: inline-block; padding: 12px 24px; background: #FF7043; color: #fff; text-decoration: none; border-radius: 8px;">Hesabımı Doğrula</a>
      <p style="color: #999; font-size: 12px; margin-top: 24px;">Bu bağlantı 24 saat geçerlidir.</p>
    </div>
  `);
};

const sendPasswordResetEmail = async (email, token) => {
  await sendMail(email, 'Bitir Yemek - Şifre Sıfırlama', `
    <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px;">
      <h2 style="color: #FF7043;">Şifre Sıfırlama</h2>
      <p>Şifrenizi sıfırlamak için aşağıdaki kodu uygulamaya girin:</p>
      <h1 style="letter-spacing: 8px; text-align: center; font-size: 36px; padding: 16px; background: #f5f5f5; border-radius: 8px; color: #333;">${token}</h1>
      <p style="color: #999; font-size: 12px; margin-top: 24px;">Bu kod 1 saat geçerlidir. Eğer bu işlemi siz yapmadıysanız bu e-postayı dikkate almayın.</p>
    </div>
  `);
};

const sendOrderStatusEmail = async (email, orderStatus, pickupCode) => {
  const statusMap = {
    confirmed: 'onaylandı',
    picked_up: 'teslim alındı',
    cancelled: 'iptal edildi',
  };
  await sendMail(email, `Bitir Yemek - Sipariş ${statusMap[orderStatus] || orderStatus}`, `
    <div style="font-family: Arial, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px;">
      <h2 style="color: #FF7043;">Sipariş Durumu Güncellendi</h2>
      <p>Siparişiniz <strong>${statusMap[orderStatus] || orderStatus}</strong>.</p>
      ${pickupCode ? `<p>Teslim alma kodunuz: <strong style="font-size: 20px; letter-spacing: 4px;">${pickupCode}</strong></p>` : ''}
    </div>
  `);
};

module.exports = {
  sendMail,
  sendOtpEmail,
  sendVerificationEmail,
  sendPasswordResetEmail,
  sendOrderStatusEmail,
};
