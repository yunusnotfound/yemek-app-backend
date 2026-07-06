"use strict";

const { v4: uuidv4 } = require("uuid");
const bcrypt = require("bcryptjs");

module.exports = {
  async up(queryInterface) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('Seed verisi production ortamında çalıştırılamaz (bilinen demo kimlik bilgileri içerir — admin@bitiryemek.com / 12345678).');
    }
    const existing = await queryInterface.sequelize.query(
      'SELECT id FROM "Users" LIMIT 1',
      { type: queryInterface.sequelize.QueryTypes.SELECT },
    );
    if (existing.length > 0) return;

    const hashedPassword = await bcrypt.hash("12345678", 10);

    await queryInterface.bulkInsert("Users", [
      {
        id: uuidv4(),
        name: "Admin Kullanıcı",
        email: "admin@bitiryemek.com",
        password: hashedPassword,
        phone: "5551112233",
        role: "admin",
        isEmailVerified: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: uuidv4(),
        name: "İşletme Sahibi 1",
        email: "owner1@bitiryemek.com",
        password: hashedPassword,
        phone: "5552223344",
        role: "business_owner",
        isEmailVerified: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: uuidv4(),
        name: "Deneme Hesabı 1",
        email: "deneme@bitiryemek.com",
        password: hashedPassword,
        phone: "5552223344",
        role: "customer",
        isEmailVerified: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: uuidv4(),
        name: "İşletme Sahibi 2",
        email: "owner2@bitiryemek.com",
        password: hashedPassword,
        phone: "5553334455",
        role: "business_owner",
        isEmailVerified: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: uuidv4(),
        name: "Müşteri 1",
        email: "customer1@example.com",
        password: hashedPassword,
        phone: "5554445566",
        role: "customer",
        isEmailVerified: true,
        latitude: 41.0082,
        longitude: 28.9784,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
      {
        id: uuidv4(),
        name: "Müşteri 2",
        email: "customer2@example.com",
        password: hashedPassword,
        phone: "5555556677",
        role: "customer",
        isEmailVerified: true,
        latitude: 41.0214,
        longitude: 29.004,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    ]);
  },

  async down(queryInterface) {
    await queryInterface.bulkDelete("Users", null, {});
  },
};
