-- =====================================================================
-- PotatoMarket 로컬 개발용 스키마
--
-- 근거
--   * 컬럼 이름 / 자료형 / 길이 / NULL / UK : 팀 ERD와 테이블 정의서
--   * 컬럼 "순서" : DAO의 rs.getInt(n) 위치와 INSERT ... VALUES 순서
--     (정의서의 표시 순서와 실제 DB 컬럼 순서가 다른 부분이 있어
--      select * 로 읽는 DAO가 깨지지 않도록 DAO 기준을 따랐습니다)
--
-- 외래키(FK)를 만들지 않은 이유
--   정의서에는 FK가 표시되어 있지만, 코드가 이를 강제하지 않았습니다.
--   예) chatRoom 생성 시 recentAdd_code 에 0 을 넣는데(users 에 없는 값),
--       이 컬럼에 FK가 실제로 걸려 있었다면 INSERT 가 실패합니다.
--   또 deleteItem 은 연관 데이터(favo, chatRoom)를 함께 지우지 않습니다.
--
-- 확정되지 않은 부분
--   * booking 테이블 : ERD/정의서에 없음(초기 설계에서 빠진 레거시).
--     BookingDAO 가 SELECT 하므로 오류 방지용으로 남겨 두었고,
--     X/Y 컬럼 이름은 추정입니다.
--   * items.booking_code : 정의서에는 없지만 DAO 가 2번째 컬럼으로 읽고 INSERT 합니다.
--   * items.cate_code 는 정의서상 카테고리 테이블 참조이지만,
--     그 테이블의 정의는 확인하지 못했고 코드에서도 사용하지 않습니다.
--   * users.user_phone 길이 : 정의서에 비어 있어 20 으로 정했습니다.
--
-- 실행: mysql -u <계정> -p < schema.sql
-- =====================================================================

CREATE DATABASE IF NOT EXISTS potatoMarket
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_general_ci;

USE potatoMarket;

-- ---------------------------------------------------------------------
-- 회원 (UserDAO)
-- 위치: 1 user_code, 2 user_id, 3 user_pw, 4 user_name, 5 user_address,
--       6 created_At, 7 modified_At, 8 user_phone
-- user_code : 1000~9999 랜덤 코드
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  user_code    INT         NOT NULL,
  user_id      VARCHAR(20) NOT NULL,
  user_pw      VARCHAR(30) NOT NULL,
  user_name    VARCHAR(10) NOT NULL,
  user_address VARCHAR(50) NULL,
  created_At   DATETIME    NULL DEFAULT CURRENT_TIMESTAMP,
  modified_At  DATETIME    NULL DEFAULT NULL,
  user_phone   VARCHAR(20) NULL,
  PRIMARY KEY (user_code),
  UNIQUE KEY uq_users_user_id (user_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 판매글 (ItemDAO)
-- 위치: 1 item_code, 2 booking_code, 3 user_code, 4 item_title,
--       5 item_contents, 6 item_price, 7 created_At, 8 modified_At,
--       9 item_selling, 10 item_pic, 11 cate_code, 12 orderuser_code
-- item_selling   : 0 = 판매중, 1 = 판매완료
-- orderuser_code : 판매완료 시 구매자 user_code (NULL 허용)
-- INSERT: values (?, null, ?, ?, ?, ?, sysdate(), sysdate(), 0, ?, 1, null)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS items (
  item_code      INT           NOT NULL,
  booking_code   INT           NULL,
  user_code      INT           NOT NULL,
  item_title     VARCHAR(50)   NOT NULL,
  item_contents  VARCHAR(2000) NULL,
  item_price     INT           NOT NULL DEFAULT 0,
  created_At     DATETIME      NULL DEFAULT CURRENT_TIMESTAMP,
  modified_At    DATETIME      NULL DEFAULT CURRENT_TIMESTAMP,
  item_selling   INT           NOT NULL DEFAULT 0,
  item_pic       VARCHAR(4000) NULL,
  cate_code      INT           NULL DEFAULT 1,
  orderuser_code INT           NULL,
  PRIMARY KEY (item_code),
  KEY idx_items_user_code (user_code),
  KEY idx_items_orderuser_code (orderuser_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 찜 목록 (FavoriteDAO)
-- 위치: 1 favo_code, 2 item_code, 3 user_code, 4 created_At, 5 modified_At
-- INSERT: (favo_code, item_code, user_code, created_At)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS favo (
  favo_code   INT      NOT NULL,
  item_code   INT      NOT NULL,
  user_code   INT      NOT NULL,
  created_At  DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  modified_At DATETIME NULL DEFAULT NULL,
  PRIMARY KEY (favo_code),
  KEY idx_favo_user_code (user_code),
  KEY idx_favo_item_user (item_code, user_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 채팅방 목록 (ChatRoomDAO)
-- 위치: 1 chat_code, 2 seller_code, 3 buyer_code, 4 item_code,
--       5 notRead_num, 6 recentAdd_code, 7 created_At, 8 modified_At
-- INSERT: values (?, ?, ?, ?, 0, 0, sysdate(), sysdate())
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chatRoom (
  chat_code      INT      NOT NULL,
  seller_code    INT      NOT NULL,
  buyer_code     INT      NOT NULL,
  item_code      INT      NOT NULL,
  notRead_num    INT      NOT NULL DEFAULT 0,
  recentAdd_code INT      NOT NULL DEFAULT 0,
  created_At     DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  modified_At    DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (chat_code),
  KEY idx_chatRoom_seller (seller_code),
  KEY idx_chatRoom_buyer (buyer_code),
  KEY idx_chatRoom_pair_item (seller_code, buyer_code, item_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 채팅 내역 (ChatHistoryDAO)
-- 위치: 1 chatNo, 2 chatRoom_code, 3 addUser, 4 chat_contents,
--       5 created_At, 6 modified_At, 7 readChat
-- INSERT: values (0, ?, ?, ?, sysdate(), sysdate(), ?)
--         첫 값 0 은 AUTO_INCREMENT 컬럼(chatNo)에 넣어 다음 번호를 받는 방식
-- readChat : 0 = 읽음, 1 = 안 읽음
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS chatHistory (
  chatNo        INT           NOT NULL AUTO_INCREMENT,
  chatRoom_code INT           NOT NULL,
  addUser       INT           NOT NULL,
  chat_contents VARCHAR(1000) NULL,
  created_At    DATETIME      NULL DEFAULT CURRENT_TIMESTAMP,
  modified_At   DATETIME      NULL DEFAULT CURRENT_TIMESTAMP,
  readChat      INT           NOT NULL DEFAULT 0,
  PRIMARY KEY (chatNo),
  KEY idx_chatHistory_room (chatRoom_code)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- 예약 (BookingDAO)  ※ 레거시: ERD/정의서에 없음, 코드에서는 SELECT만 존재
-- 위치: 1 booking_code, 2 item_code, 3 X, 4 Y, 5 user_codeA, 6 user_codeB,
--       7 created_At, 8 modified_At   (X, Y 이름은 추정)
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS booking (
  booking_code INT      NOT NULL,
  item_code    INT      NOT NULL,
  booking_x    INT      NULL,
  booking_y    INT      NULL,
  user_codeA   INT      NULL,
  user_codeB   INT      NULL,
  created_At   DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  modified_At  DATETIME NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (booking_code),
  KEY idx_booking_user_codeB (user_codeB)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
