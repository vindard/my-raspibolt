drop database if exists mempool;
create database mempool;
grant all privileges on mempool.* to 'mempool'@'%' identified by 'mempool';
