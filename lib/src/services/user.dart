import 'package:angel_common/angel_common.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:mongo_dart/mongo_dart.dart';
import 'package:random_string/random_string.dart' as rs;
import '../models/user.dart';
import '../validators/user.dart';
export '../models/user.dart';

configureServer(Db db) {
  return (Angel app) async {
    app.use('/api/users', new UserService(db.collection('users')));

    HookedService service = app.service('api/users');
    app.container.singleton(service.inner);

    service.beforeCreated
      ..listen(validateEvent(CREATE_USER))
      ..listen((e) {
        var salt = rs.randomAlphaNumeric(12);
        e.data
          ..['password'] =
              hashPassword(e.data['password'], salt, app.jwt_secret)
          ..['salt'] = salt;
      });
  };
}

/// SHA-256 hash any string, particularly a password.
String hashPassword(String password, String salt, String pepper) =>
    sha256.convert(('$salt:$password:$pepper').codeUnits).toString();

/// Manages users.
///
/// Here, we extended the base service class. This allows to only expose
/// specific methods, and also allows more freedom over things such as validation.
class UserService extends TypedService<User> {
  UserService(DbCollection collection) : super(new MongoService(collection));

  @override
  index([Map params]) {
    if (params != null && params.containsKey('provider')) {
      // Nobody needs to see the entire user list except for the server.
      throw new AngelHttpException.forbidden();
    }

    return super.index(params);
  }

  @override
  create(data, [Map params]) {
    if (params != null && params.containsKey('provider')) {
      // Deny creating users to the public - this should be done by the server only.
      throw new AngelHttpException.forbidden();
    }

    return super.create(data, params);
  }
}
